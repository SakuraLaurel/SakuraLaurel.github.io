下面这套目标不是“把 C++ 写成 Rust 语法”，而是把 C++ 约束到一个**更小、更现代、更显式、更可静态分析的子集**：RAII、值语义、显式所有权、少共享可变状态、显式错误返回、少宏、少裸指针、少隐式转换、模板用 concepts 约束。

## 1. 先定“风格基线”：不要只开 clang-tidy

公开的大厂做法有一个共同点：**不是靠单一工具，而是靠风格指南 + 编译器警告 + 格式化 + 静态分析 + CI 门禁**。

Google C++ Style Guide 明确说多数 Google 开源 C++ 项目遵循该指南，并且 Google 风格里包括 cpplint、禁止自有代码使用 C++ exceptions、倾向单一固定 owner 与智能指针表达所有权等规则。([Google][1]) Chromium 继承 Google C++ Style Guide，并要求接受 clang-format 的格式化结果；它还有单独的“Modern C++ features”白名单/状态文档，而不是新标准一出就全量放开。([Chromium Git Repositories][2]) LLVM 的公开规范则强调标准、现代、可移植 C++，默认 LLVM 子项目使用 C++17，并包含降低嵌套、early exit、range-based loop 等可读性准则。([LLVM][3]) Mozilla 也明确把部分 Google C++ 规则和 Mozilla 自有规则通过 clang-tidy 或插件检查。([Firefox 源码文档][4])

所以推荐基线是：

```text
clang-format 负责格式统一
compiler warnings 负责语言层面硬错误
clang-tidy 负责现代化、bug-prone、Core Guidelines、readability、performance
include-what-you-use 负责头文件依赖卫生
sanitizers 负责运行期内存/UB/线程错误
CI 负责把这些变成不可绕过的门禁
```

## 2. 推荐工具链

### 必选工具

| 工具                                | 作用                       | 建议                                       |
| --------------------------------- | ------------------------ | ---------------------------------------- |
| `clang-format`                    | 统一格式                     | 直接用 Google/LLVM/Chromium-like 风格，团队不要争格式 |
| `clang-tidy`                      | 现代化、静态检查、Core Guidelines | 新代码严格，旧代码分阶段治理                           |
| `clang++` / `g++` / MSVC warnings | 编译器级别约束                  | CI 中把新增 warning 视为失败                     |
| `include-what-you-use`            | 去除隐式头文件依赖                | 大型 C++ 项目非常有价值                           |
| ASan/UBSan/TSan                   | 运行期安全网                   | 测试、CI、fuzz 使用，不进生产二进制                    |
| `clangd`                          | IDE 即时反馈                 | 让风格约束前移到编辑阶段                             |

`clang-tidy` 支持按 check 名称或 glob 启用/禁用检查，也可以运行 Clang Static Analyzer 检查；官方文档把检查分成 `bugprone-`、`cppcoreguidelines-`、`modernize-`、`performance-`、`readability-`、`clang-analyzer-` 等组。([Clang][5]) 它依赖 `compile_commands.json` 获取真实编译参数，CMake 可用 `-DCMAKE_EXPORT_COMPILE_COMMANDS=ON` 生成；大项目应使用 `run-clang-tidy.py` 并行跑，review/CI 可用 `clang-tidy-diff.py` 聚焦 diff，但重大改动仍应跑完整文件或全项目。([Clang][5])

`include-what-you-use` 的目标是让每个源文件/头文件包含自己实际使用符号所需的头，并去掉多余 include 或替换成前向声明。([Include What You Use][6]) ASan 是 bug detection 工具，Clang 文档明确不建议把 ASan runtime 链进生产可执行文件；UBSan 支持多类未定义行为检测与抑制配置。([Clang][7])

## 3. 建议的 `clang-tidy` 配置

新项目或新模块可以从这个强配置开始。旧项目建议先只对新增/修改代码启用，避免一次性爆炸。

```yaml
Checks: >
  -*,
  clang-diagnostic-*,
  clang-analyzer-*,
  bugprone-*,
  performance-*,
  portability-*,
  modernize-*,
  readability-*,
  cppcoreguidelines-*,
  concurrency-*,
  misc-*,
  -readability-magic-numbers,
  -cppcoreguidelines-avoid-magic-numbers,
  -modernize-use-trailing-return-type,
  -cppcoreguidelines-avoid-do-while,
  -cppcoreguidelines-pro-bounds-pointer-arithmetic,
  -cppcoreguidelines-pro-type-vararg,
  -cppcoreguidelines-avoid-non-const-global-variables

WarningsAsErrors: >
  clang-analyzer-*,
  bugprone-*,
  cppcoreguidelines-owning-memory,
  cppcoreguidelines-pro-type-*,
  cppcoreguidelines-pro-bounds-*,
  modernize-*,
  performance-*,
  concurrency-*

HeaderFilterRegex: '^(src|include)/'
FormatStyle: file
InheritParentConfig: true

CheckOptions:
  readability-function-size.LineThreshold: '80'
  readability-function-size.StatementThreshold: '50'
  readability-function-size.BranchThreshold: '10'

  readability-identifier-naming.ClassCase: CamelCase
  readability-identifier-naming.StructCase: CamelCase
  readability-identifier-naming.EnumCase: CamelCase
  readability-identifier-naming.FunctionCase: lower_case
  readability-identifier-naming.VariableCase: lower_case
  readability-identifier-naming.MemberCase: lower_case
  readability-identifier-naming.PrivateMemberSuffix: '_'
  readability-identifier-naming.ConstantCase: CamelCase
  readability-identifier-naming.ConstantPrefix: 'k'
```

几点说明：

`modernize-*` 不等于“C++23/Rust-like 全自动”，官方说明里 `modernize-` 是倡导现代 C++ 构造，历史上“modern”主要指 C++11 起的构造；所以你还需要手写团队规则，例如 `expected`、`span`、`ranges`、`concepts` 的使用策略。([Clang][5])

`cppcoreguidelines-*` 很有价值，但噪声也较高。C++ Core Guidelines 的目标是让 C++ 更简单、高效、可维护，同时它也承认大型组织和项目通常需要额外限制与库支持。([C++ 标准基金会][8]) Microsoft 的 C++ Core Guidelines checker 也只是支持规则子集，并强调这些准则关注静态类型安全与资源安全。([Microsoft Learn][9])

`abseil-*`、`google-*`、`llvm-*` 不建议无脑全开。使用 Abseil 就开 `abseil-*`；走 Google 风格就开 `google-*`；贡献 LLVM 项目才开 `llvm-*`。clang-tidy 官方检查列表里这些是按生态/项目风格分组的，不是通用“越多越好”。([Clang][5])

## 4. 命令落地

CMake：

```bash
cmake -S . -B build \
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
  -DCMAKE_CXX_STANDARD=23 \
  -DCMAKE_CXX_STANDARD_REQUIRED=ON \
  -DCMAKE_CXX_EXTENSIONS=OFF
```

全量 clang-tidy：

```bash
run-clang-tidy.py -p build -j 8
```

只检查当前 PR diff：

```bash
git diff -U0 --no-color origin/main...HEAD \
  | clang-tidy-diff.py -p1 -path build
```

自动修复部分问题：

```bash
run-clang-tidy.py -p build -j 8 -fix -format-style=file
```

clang-tidy 官方支持 `--fix` 应用 fix-it，支持 `--warnings-as-errors` 把匹配检查升级为错误，也支持 `NOLINT`、`NOLINTNEXTLINE`、`NOLINTBEGIN`/`NOLINTEND` 抑制诊断；建议团队规定：**每个 NOLINT 必须写原因**。([Clang][5])

编译器警告建议：

```bash
-Wall -Wextra -Wpedantic
-Wconversion -Wsign-conversion
-Wshadow
-Wold-style-cast
-Wnon-virtual-dtor
-Woverloaded-virtual
-Wnull-dereference
-Wdouble-promotion
-Wformat=2
```

新代码可以 `-Werror`，旧代码更建议“新增 warning 不得增加”的 baseline 策略。

Sanitizer 测试配置：

```bash
# 内存越界、use-after-free、UB
-fsanitize=address,undefined -fno-omit-frame-pointer -g

# 线程数据竞争，单独 job 跑
-fsanitize=thread -g
```

## 5. Rust-like C++ 编码规则

### 5.1 所有权：默认值语义，显式 owner，借用不拥有

推荐规则：

```cpp
// 好：值语义
struct User {
  std::string name;
  int age = 0;
};

// 好：唯一所有权
std::unique_ptr<Foo> make_foo();

// 好：非拥有借用
void render(std::span<const Pixel> pixels);
void log(std::string_view message);

// 坏：裸 owning pointer
Foo* make_foo();  // 谁 delete？生命周期在哪里？
```

对应约束：

```yaml
Checks: >
  cppcoreguidelines-owning-memory,
  cppcoreguidelines-pro-type-member-init,
  cppcoreguidelines-special-member-functions,
  modernize-make-unique,
  modernize-make-shared,
  bugprone-use-after-move,
  bugprone-dangling-handle
```

Google 风格公开建议动态对象尽量有单一固定 owner，所有权转移优先用 smart pointer，`std::unique_ptr` 表达独占所有权，`std::shared_ptr` 只在确有共享所有权理由时使用。([Google][10]) GSL 也提供 Core Guidelines 建议的类型与函数，例如用于表达 guideline 语义的支持库；clang-tidy 的 `cppcoreguidelines-owning-memory` 会识别 `gsl::owner<T*>` 这类所有权意图。([GitHub][11])

### 5.2 错误处理：用 `expected` / `StatusOr`，少用异常做业务流

Rust-like 的 `Result<T, E>` 在 C++23 最接近的是：

```cpp
#include <expected>

enum class ParseError {
  Empty,
  InvalidFormat,
};

std::expected<int, ParseError> parse_int(std::string_view text);
```

`std::expected` 是 C++23 的标准库类型，用来表示“预期值 T 或非预期值 E”。([C++参考文献][12]) Google 风格禁止自有代码使用 C++ exceptions，原因是既有大规模代码库不具备异常传播/异常安全假设；这不是“异常绝对错误”，而是大型代码库一致性和可维护性的工程选择。([Google][10])

建议二选一，不要混用：

```text
Google/Chromium-like 服务端风格：
  -fno-exceptions
  std::expected<T, E> / absl::StatusOr<T> / 自研 Result<T,E>

标准库/库作者风格：
  exceptions 可用，但必须有异常安全策略、边界转换、noexcept 策略
```

### 5.3 不可变性：默认少写共享 mutable state

推荐：

```cpp
struct Config {
  std::string endpoint;
  int timeout_ms = 1000;
};

void start_server(const Config& config);  // 只读借用
```

避免：

```cpp
extern Config g_config;        // 可变全局
static std::string cache;      // 非平凡静态对象，初始化/析构顺序风险
```

Google 风格对 static/global 对象限制很强，静态存储期对象除非 trivially destructible 否则禁止，并限制动态初始化。([Google][10]) Rust-like C++ 应该把可变状态压到边界：IO、缓存、数据库连接、线程同步对象集中封装，不要让业务函数到处读写全局状态。

### 5.4 类型建模：用 `enum class`、`variant`、`optional`，少用 bool/int/string 魔法值

推荐：

```cpp
enum class DeviceState {
  Disconnected,
  Connecting,
  Connected,
  Failed,
};

struct Disconnected {};
struct Connecting { int retry_count; };
struct Connected { ConnectionId id; };
struct Failed { ErrorCode code; };

using State = std::variant<Disconnected, Connecting, Connected, Failed>;
```

对应约束：

```yaml
Checks: >
  cppcoreguidelines-use-enum-class,
  bugprone-switch-missing-default-case,
  bugprone-unhandled-self-assignment,
  readability-implicit-bool-conversion
```

同时建议开启编译器警告：

```bash
-Wswitch-enum
```

策略上，**枚举状态机不要写 default**，让编译器在新增枚举值时提示未处理分支。这一点非常接近 Rust `match` 的“穷尽性”心智模型，虽然 C++ 无法做到同等级别保证。

### 5.5 函数式风格：小函数、纯函数、ranges、算法优先

推荐：

```cpp
auto active_names(const std::vector<User>& users) -> std::vector<std::string> {
  auto names = std::vector<std::string>{};

  for (const auto& user : users) {
    if (!user.active) {
      continue;
    }
    names.push_back(user.name);
  }

  return names;
}
```

如果项目已稳定使用 C++20/23 ranges，可以进一步写成 pipeline，但不要为了“函数式”牺牲可读性：

```cpp
auto names =
    users
    | std::views::filter([](const User& u) { return u.active; })
    | std::views::transform([](const User& u) -> std::string_view { return u.name; });
```

对应约束：

```yaml
Checks: >
  modernize-loop-convert,
  modernize-use-auto,
  modernize-use-ranges,
  readability-function-size,
  readability-else-after-return,
  readability-simplify-boolean-expr,
  misc-const-correctness
```

LLVM 规范也强调 early exits、减少嵌套、range-based loop 等可读性实践。([LLVM][13])

### 5.6 模板：用 concepts/requires，不要 SFINAE 地狱

推荐：

```cpp
template <std::ranges::range R>
requires std::same_as<std::ranges::range_value_t<R>, int>
auto sum(R&& values) -> int {
  return std::accumulate(std::begin(values), std::end(values), 0);
}
```

对应约束：

```yaml
Checks: >
  modernize-use-constraints,
  readability-identifier-naming,
  bugprone-forwarding-reference-overload,
  cppcoreguidelines-missing-std-forward
```

clang-tidy 检查列表中已有 `modernize-use-constraints`，适合把旧式 `enable_if`/SFINAE 逐步迁到 C++20 constraints/concepts 风格。([Clang][14])

## 6. 推荐团队规则：一页版

可以直接作为团队 C++ profile：

```text
语言标准：
  C++20 起步；新项目优先 C++23；禁止 compiler-specific extension，除非封装在 platform 层。

所有权：
  默认值语义。
  owning heap object 用 std::unique_ptr。
  shared ownership 需要设计评审；优先 std::shared_ptr<const T>。
  裸指针、reference、span、string_view 均视为 non-owning borrow。
  禁止 new/delete 出现在业务代码中。

错误处理：
  业务可恢复错误返回 std::expected<T,E> / StatusOr<T>。
  不用 int/bool/nullptr 表示多种错误。
  panic/fatal/assert 只用于不变量破坏，不用于用户输入错误。

可变性：
  禁止可变全局状态。
  函数入参能 const 就 const。
  side effects 放在边界层，核心逻辑写成纯函数或近似纯函数。

类型：
  禁止 unscoped enum；使用 enum class。
  状态组合优先 variant/struct，不用 string/int 魔法值。
  optional 表示“可能没有值”，expected 表示“可能失败”。

并发：
  不共享可变数据，必须共享时封装 mutex/atomic。
  禁止裸 thread detach。
  TSan 定期跑。

模板：
  C++20 concepts/requires 优先。
  模板错误信息必须可读。
  避免宏元编程。

头文件：
  self-contained header。
  每个文件 include 自己真正使用的头。
  定期跑 include-what-you-use。

例外：
  NOLINT 必须带原因。
  违反 profile 的代码必须在 review 中解释。
```

## 7. CI 门禁建议

最实用的是分层门禁：

```text
本地/IDE：
  clangd + clang-format on save + clang-tidy hints

pre-commit：
  clang-format
  轻量 clang-tidy-diff

PR：
  编译器 warnings
  clang-tidy-diff
  单元测试
  ASan + UBSan 测试 job

nightly/full：
  run-clang-tidy.py 全量
  include-what-you-use
  TSan
  fuzz/property tests
  dependency/license/security scanning
```

不要一开始就让旧仓库全量 `WarningsAsErrors=*`。更工程化的做法是：

```text
第 1 周：生成 baseline，只拦截新增问题
第 2-4 周：修 bugprone / analyzer / sanitizer 真 bug
第 2 月：打开 ownership / bounds / type safety
第 3 月：推动 modernize / readability
之后：新模块使用严格 profile，旧模块逐步迁移
```

## 8. 最重要的边界：C++ 不会真正拥有 Rust borrow checker

可以做到“像 Rust 的工程风格”：

```text
显式 ownership
少 shared mutable state
Result-like error handling
sum type 建模
RAII
强 lint
强 CI
sanitizer
小函数/纯函数
```

但做不到 Rust 那种编译期生命周期完备证明。`std::span`、`std::string_view`、裸引用都只是 non-owning view；工具能抓很多错误，但不能证明所有 borrow 都安全。因此 Rust-like C++ 的核心不是“多写 ranges/lambda”，而是：

```text
把危险能力局部化；
把所有权写进类型；
把错误写进返回值；
把约束写进工具和 CI；
把例外写进审查记录。
```

这才是接近大规模工程里“现代、标准、函数式、Rust-like C++”的可持续路径。

[1]: https://google.github.io/styleguide/cppguide.html?utm_source=chatgpt.com "Google C++ Style Guide - GitHub"
[2]: https://chromium.googlesource.com/chromium/src/%2B/HEAD/styleguide/c%2B%2B/c%2B%2B.md?utm_source=chatgpt.com "Chromium C++ style guide - Google Open Source"
[3]: https://llvm.org/docs/CodingStandards.html?utm_source=chatgpt.com "LLVM Coding Standards — LLVM 23.0.0git documentation"
[4]: https://firefox-source-docs.mozilla.org/code-quality/coding-style/coding_style_cpp.html?utm_source=chatgpt.com "C++ Coding style — Firefox Source Docs documentation - Mozilla"
[5]: https://clang.llvm.org/extra/clang-tidy/ "Clang-Tidy — Extra Clang Tools 23.0.0git documentation"
[6]: https://include-what-you-use.org/ "include-what-you-use - A tool for use with clang to analyze #includes in C and C++ source files"
[7]: https://clang.llvm.org/docs/AddressSanitizer.html "AddressSanitizer — Clang 23.0.0git documentation"
[8]: https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines "C++ Core Guidelines"
[9]: https://learn.microsoft.com/zh-cn/cpp/code-quality/using-the-cpp-core-guidelines-checkers?view=msvc-170&utm_source=chatgpt.com "使用 C++ 核心准则检查工具 | Microsoft Learn"
[10]: https://google.github.io/styleguide/cppguide.html "Google C++ Style Guide"
[11]: https://github.com/microsoft/GSL?utm_source=chatgpt.com "GitHub - microsoft/GSL: Guidelines Support Library"
[12]: https://en.cppreference.com/cpp/utility/expected?utm_source=chatgpt.com "std::expected - cppreference.com"
[13]: https://llvm.org/docs/CodingStandards.html "LLVM Coding Standards — LLVM 23.0.0git documentation"
[14]: https://clang.llvm.org/extra/clang-tidy/checks/list.html?utm_source=chatgpt.com "clang-tidy - Clang-Tidy Checks — Extra Clang Tools 23.0.0git documentation"


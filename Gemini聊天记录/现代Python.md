下面是我建议的“2026 年现代 Python 约束栈”。核心思想不是“装很多工具”，而是把**格式、静态语义、类型、依赖、安全、测试**都变成可重复执行的 gate。

## 1. 推荐工具分层

| 层级                         | 工具                        | 作用                                                                                                              |
| -------------------------- | ------------------------- | --------------------------------------------------------------------------------------------------------------- |
| 项目与环境                      | `uv`                      | 管 Python 版本、虚拟环境、依赖、lockfile、工具运行；它定位上可替代 `pip/pip-tools/pipx/poetry/pyenv/virtualenv` 等很多场景。([Astral Docs][1]) |
| 格式 + lint + import + 现代化重写 | `ruff`                    | 替代 Black、isort、Flake8 及大量插件；支持 900+ 规则、自动修复、pyproject 配置、monorepo 配置。([Astral Docs][2])                         |
| 类型检查                       | `ty`                      | Astral 的高速类型检查器和 language server；默认比 mypy/pyright 常规模式更严格，支持增量分析、IDE 集成、规则级别配置。([Astral Docs][3])               |
| 兼容性二次检查                    | `pyright` 或 `mypy`        | 在 ty 尚未完全覆盖 mypy/pyright 的所有诊断时，关键项目可以并跑一个成熟 checker。ty 官方也说明有若干 mypy/pyright 检查尚未实现。([Astral Docs][4])         |
| 测试                         | `pytest` + `hypothesis`   | pytest 做单测，Hypothesis 做 property-based testing，尤其适合函数式/纯函数代码的性质验证。([Hypothesis 文档][5])                          |
| 依赖治理                       | `deptry`                  | 查未使用、缺失、传递依赖泄漏。([PyPI][6])                                                                                      |
| 安全                         | `pip-audit` + 可选 `bandit` | `pip-audit` 查已知漏洞依赖，Bandit 做常见 Python 安全问题的 AST 扫描。([GitHub][7])                                                |

Python 版本建议：新项目优先 `>=3.12`，条件允许可 `>=3.13` 或 `>=3.14`。截至 2026-06，Python 3.14 和 3.13 是 bugfix 状态，3.12/3.11/3.10 是 security 状态；3.14.0 已在 2025-10-07 final，3.14.6 已在 2026-06-10 发布。([Python Developer's Guide][8])

---

## 2. 一个可直接采用的 `pyproject.toml`

这套配置偏“现代、严格、函数式友好”，但没有盲目 `select = ["ALL"]`，因为那会引入很多组织风格争议。

```toml
[project]
requires-python = ">=3.12"
dependencies = []

[dependency-groups]
dev = [
  "ruff",
  "ty",
  "pytest",
  "hypothesis",
  "deptry",
  "pip-audit",
  "bandit",
]

[tool.ruff]
line-length = 100
indent-width = 4
target-version = "py312"
src = ["src", "tests"]
fix = true
show-fixes = true

[tool.ruff.format]
quote-style = "double"
indent-style = "space"
line-ending = "auto"
docstring-code-format = true

[tool.ruff.lint]
select = [
  "E",      # pycodestyle errors
  "F",      # Pyflakes
  "W",      # pycodestyle warnings
  "I",      # isort
  "UP",     # pyupgrade
  "B",      # flake8-bugbear
  "C4",     # flake8-comprehensions
  "SIM",    # flake8-simplify
  "RET",    # flake8-return
  "ARG",    # unused arguments
  "PTH",    # pathlib over os.path
  "PIE",    # flake8-pie
  "N",      # naming
  "PL",     # selected Pylint rules
  "RUF",    # Ruff-specific rules
  "ANN",    # annotations
  "ASYNC",  # async correctness
  "SLOT",   # __slots__ opportunities
  "PERF",   # performance footguns
  "TID",    # tidy imports
  "TC",     # type-checking imports
  "FBT",    # boolean trap
  "PT",     # pytest style
  "DTZ",    # timezone-aware datetime
  "TRY",    # exception style
  "EM",     # error message style
  "PGH",    # pygrep hooks, specific ignores
]

ignore = [
  "E501",    # format handles wrapping; long URLs/messages may remain
  "ANN401",  # allow explicit Any when deliberately documented
]

fixable = ["ALL"]

[tool.ruff.lint.per-file-ignores]
"tests/**" = [
  "S101",     # assert is expected in tests
  "ANN201",   # test return annotations are optional
  "PLR2004",  # magic values in tests are often fine
]
"__init__.py" = ["F401"]

[tool.ruff.lint.pydocstyle]
convention = "google"

[tool.ruff.lint.pylint]
max-args = 5
max-branches = 12
max-returns = 4
max-statements = 50

[tool.ty.environment]
python-version = "3.12"
root = ["./src"]

[tool.ty.rules]
missing-type-argument = "error"
possibly-unresolved-reference = "warn"

[tool.ty.terminal]
error-on-warning = true
```

ty 官方给出的“接近 strict”的建议也是：不要简单 `--error=all`，而是启用 `missing-type-argument`、把 `possibly-unresolved-reference` 设为 warning，并用 Ruff 的 `ANN`、`PYI` 等规则补足类型注解约束。([Astral Docs][4])

---

## 3. 日常命令

```bash
uv sync

uv run ruff check --fix .
uv run ruff format .

uv run ty check

uv run pytest

uv run deptry .
uv run pip-audit
uv run bandit -r src
```

CI 里不要自动修复，只检查：

```bash
uv sync --locked --dev

uv run ruff format --check .
uv run ruff check .
uv run ty check
uv run pytest
uv run deptry .
uv run pip-audit
uv run bandit -r src
```

---

## 4. “函数式 Python” 应该怎么写

Python 里的函数式风格不等于强行写 Haskell。更准确的目标是：

**pure core, imperative shell**：核心业务逻辑尽量是纯函数；I/O、数据库、网络、时间、随机数、环境变量放在边界层。

推荐模式：

```python
from dataclasses import dataclass
from collections.abc import Iterable, Mapping, Sequence
from decimal import Decimal


@dataclass(frozen=True, slots=True, kw_only=True)
class OrderLine:
    sku: str
    quantity: int
    unit_price: Decimal


@dataclass(frozen=True, slots=True, kw_only=True)
class Invoice:
    customer_id: str
    lines: tuple[OrderLine, ...]


def line_total(line: OrderLine) -> Decimal:
    return line.unit_price * line.quantity


def invoice_total(invoice: Invoice) -> Decimal:
    return sum(map(line_total, invoice.lines), start=Decimal("0"))


def eligible_for_discount(invoice: Invoice, *, threshold: Decimal) -> bool:
    return invoice_total(invoice) >= threshold
```

关键约束：

1. **数据默认不可变**：优先 `@dataclass(frozen=True, slots=True, kw_only=True)`，跨边界传 `tuple`、`Mapping`、`Sequence`，少传可变 `list`/`dict`。
2. **函数显式输入输出**：少用全局变量、单例、隐式缓存、环境变量直读。
3. **少用副作用装饰器、反射、monkey patch**：Google Python Style Guide 明确建议谨慎使用 decorator，避免“power features”，并且更偏好模块级函数而不是无必要的 `staticmethod`。([Google][9])
4. **类型表达业务约束**：用 `Literal`、`Enum`、`NewType`、`Protocol`、`TypedDict`、泛型 type alias，而不是到处 `str`/`dict[str, Any]`。
5. **错误要类型化或异常化，不要混乱返回**：`T | None` 必须有语义；失败原因复杂时用明确异常或结果对象。
6. **组合优先于继承**：模块级纯函数 + 小 dataclass 往往比深继承树更易测、更易类型检查。
7. **property-based tests 很适合纯函数**：例如金额计算、排序、归一化、解析器、状态转换，都可以写不变量测试。

---

## 5. 类型写法：用现代语法，但别过度炫技

Python 3.12+ 可以使用 PEP 695 的类型参数语法和 `type` alias，新语法更适合现代项目。PEP 695 明确引入了泛型函数、泛型类和类型别名的新语法。([Python Enhancement Proposals (PEPs)][10])

```python
from collections.abc import Callable, Iterable, Mapping
from typing import Protocol, NewType

UserId = NewType("UserId", int)

type Predicate[T] = Callable[[T], bool]
type Index[K, V] = Mapping[K, V]


class HasId(Protocol):
    id: UserId


def first[T](items: Iterable[T], predicate: Predicate[T]) -> T | None:
    return next((item for item in items if predicate(item)), None)
```

建议：

* 公共函数必须标注参数和返回值。
* 内部局部变量能推导就不写，不能推导才写。
* 不要滥用 `cast()`；每个 `cast()` 都应像“债务”一样被审查。
* `Any` 只能出现在边界层，比如 JSON、第三方库、动态插件系统；核心逻辑禁止扩散。
* 对第三方库缺类型的情况，优先安装 stub 包、写局部 `.pyi`，最后才 `replace-imports-with-any`。

---

## 6. 大厂做法可以借鉴什么

**Google** 的 Python 风格更强调可读性、简单结构、谨慎使用动态高级特性；这和“现代函数式 Python”的方向一致：少魔法、少隐式、模块级函数优先。([Google][9])

**Dropbox** 的经验是大规模 Python 必须逐步提高类型覆盖率：他们在数百万行 Python 上推进 mypy，最后要求新文件和多数既有文件有类型注解，并通过覆盖率报告、编辑器集成、性能优化来降低迁移成本。([dropbox.tech][11])

**Meta** 的路线是高速增量类型检查和安全静态分析：Pyre 面向百万行级代码库、支持渐进类型，且带有 Pysa 做数据流安全分析；Pyrefly 是其下一代高速 type checker/language server。([pyre-check.org][12])

**Microsoft/Pyright** 的价值是高性能、标准兼容、VS Code/Pylance 生态成熟；在 ty 迁移期，把 pyright 作为第二 checker 是很稳妥的选择。([GitHub][13])

抽象成团队规则就是：**新代码严格，老代码分区渐进；本地快，CI 硬；类型覆盖率可视化；例外必须有注释和 owner。**

---

## 7. 我建议的落地顺序

第一阶段：只上 `uv + ruff format + ruff check`，开启自动修复，先统一风格。

第二阶段：打开 `ANN`、`B`、`C4`、`SIM`、`RET`、`PTH`、`FBT`、`PL`，把函数复杂度、可变状态、布尔陷阱、过度命令式写法压下来。

第三阶段：上 `ty check`，新代码必须全类型，老代码按目录逐步纳入。

第四阶段：核心包加 `pyright` 或 `mypy` 二次检查，直到 ty 对你的代码模式足够稳定。

第五阶段：加 `hypothesis`、`deptry`、`pip-audit`、`bandit`，让“函数行为、依赖边界、安全风险”也进入约束系统。

最终标准可以概括为一句话：

> **Ruff 负责代码形态，ty/pyright 负责静态语义，pytest/Hypothesis 负责行为不变量，uv 负责可复现环境，CI 负责让这些规则不可绕过。**

[1]: https://docs.astral.sh/uv/ "uv"
[2]: https://docs.astral.sh/ruff/ "Ruff"
[3]: https://docs.astral.sh/ty/ "ty"
[4]: https://docs.astral.sh/ty/coming-from-mypy-or-pyright/ "Coming from mypy, pyright | ty"
[5]: https://hypothesis.readthedocs.io/?utm_source=chatgpt.com "Hypothesis 6.155.7 documentation"
[6]: https://pypi.org/project/deptry/?utm_source=chatgpt.com "deptry · PyPI"
[7]: https://github.com/pypa/pip-audit?utm_source=chatgpt.com "GitHub - pypa/pip-audit: Audits Python environments, requirements files ..."
[8]: https://devguide.python.org/versions/ "Status of Python versions"
[9]: https://google.github.io/styleguide/pyguide.html "styleguide | Style guides for Google-originated open-source projects"
[10]: https://peps.python.org/pep-0695/?utm_source=chatgpt.com "PEP 695 – Type Parameter Syntax | peps.python.org"
[11]: https://dropbox.tech/application/our-journey-to-type-checking-4-million-lines-of-python "Our journey to type checking 4 million lines of Python - Dropbox"
[12]: https://pyre-check.org/ "Pyre | Pyre"
[13]: https://github.com/microsoft/pyright "GitHub - microsoft/pyright: Static Type Checker for Python · GitHub"


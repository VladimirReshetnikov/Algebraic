"""A small, whitelisted radical straight-line language (no eval or sympify of input)."""
from __future__ import annotations
from dataclasses import dataclass
from typing import Any
import re
import sympy as s

_INT = re.compile(r"-?(?:0|[1-9][0-9]*)\Z")

def integer(text: Any) -> s.Integer:
    if not isinstance(text, str) or not _INT.fullmatch(text):
        raise ValueError("Integers must be canonical signed decimal strings")
    return s.Integer(text)

def radical_expression(expr: s.Expr) -> bool:
    """True only for finite expressions over Q and I using +, *, rational powers."""
    if expr.is_Rational or expr == s.I:
        return True
    if expr.is_Add or expr.is_Mul:
        return all(radical_expression(a) for a in expr.args)
    return bool(expr.is_Pow and expr.exp.is_Rational and radical_expression(expr.base))

@dataclass
class RadicalProgram:
    """Assignments are ordered; each may refer only to previous register symbols."""
    assignments: list[tuple[s.Symbol, s.Expr]]
    output: s.Expr

    @classmethod
    def from_expr(cls, expr: s.Expr) -> "RadicalProgram":
        if not radical_expression(expr):
            raise ValueError("Expression is not a radical expression over Q")
        return cls([], expr)

    def expression(self, max_nodes: int | None = 100000) -> s.Expr:
        env: dict[s.Symbol, s.Expr] = {}
        for name, rhs in self.assignments:
            env[name] = rhs.xreplace(env)
        ans = self.output.xreplace(env)
        if max_nodes is not None:
            count = 0
            for _ in s.preorder_traversal(ans):
                count += 1
                if count > max_nodes:
                    raise ValueError("Expanded expression exceeds max_nodes; use the DAG")
        return ans

    def to_json(self) -> dict[str, Any]:
        nodes: list[dict[str, Any]] = []
        memo: dict[s.Expr, int] = {}
        env: dict[s.Symbol, int] = {}
        def emit(e: s.Expr) -> int:
            if e in env:
                return env[e]
            if e in memo:
                return memo[e]
            if e.is_Rational:
                obj = {"op": "Q", "n": str(e.p), "d": str(e.q)}
            elif e == s.I:
                obj = {"op": "I"}
            elif e.is_Add or e.is_Mul:
                obj = {"op": "Add" if e.is_Add else "Mul", "args": [emit(a) for a in e.args]}
            elif e.is_Pow and e.exp.is_Rational:
                obj = {"op": "Pow", "base": emit(e.base), "n": str(e.exp.p), "d": str(e.exp.q)}
            else:
                raise ValueError(f"Unsupported node: {e.func}")
            idx = len(nodes)
            nodes.append(obj)
            memo[e] = idx
            return idx
        registers = []
        for name, rhs in self.assignments:
            idx = emit(rhs)
            env[name] = idx
            registers.append({"name": str(name), "node": idx})
        out = emit(self.output)
        return {"format": "rootradicals-dag-v1", "nodes": nodes,
                "registers": registers, "output": out}

    @classmethod
    def from_json(cls, obj: dict[str, Any]) -> "RadicalProgram":
        if obj.get("format") != "rootradicals-dag-v1":
            raise ValueError("Unsupported DAG format")
        vals: list[s.Expr] = []
        def ref(k: Any) -> s.Expr:
            if type(k) is not int or not 0 <= k < len(vals):
                raise ValueError("DAG references must point strictly backward")
            return vals[k]
        for node in obj["nodes"]:
            op = node["op"]
            if op == "Q":
                n, d = integer(node["n"]), integer(node["d"])
                if d <= 0: raise ValueError("Denominator must be positive")
                v = s.Rational(n, d)
            elif op == "I": v = s.I
            elif op in ("Add", "Mul"):
                args = [ref(i) for i in node["args"]]
                v = s.Add(*args) if op == "Add" else s.Mul(*args)
            elif op == "Pow":
                base = ref(node["base"])
                n, d = integer(node["n"]), integer(node["d"])
                if d <= 0: raise ValueError("Denominator must be positive")
                if base == 0 and n <= 0: raise ValueError("Undefined power")
                v = s.Pow(base, s.Rational(n, d))
            else: raise ValueError("Unknown DAG operation")
            if v.has(s.zoo, s.oo, -s.oo, s.nan):
                raise ValueError("Nonfinite radical expression")
            vals.append(v)
        k = obj["output"]
        if type(k) is not int or not 0 <= k < len(vals):
            raise ValueError("Invalid output reference")
        return cls.from_expr(vals[k])

    def wolfram(self) -> str:
        """Emit a nested With program, retaining sharing rather than textual expansion."""
        from sympy.printing.mathematica import mathematica_code
        out = mathematica_code(self.output)
        for name, rhs in reversed(self.assignments):
            out = f"With[{{{name} = {mathematica_code(rhs)}}}, {out}]"
        return out

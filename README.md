# ledgerex

[![Apache License](https://img.shields.io/hexpm/l/ledgerex)](LICENSE.md)
[![Hex.pm](https://img.shields.io/hexpm/v/ledgerex)](https://hex.pm/packages/ledgerex)
[![Documentation](https://img.shields.io/badge/hexdocs-latest-blue.svg)](https://hexdocs.pm/ledgerex/index.html)
[![Build Status](https://travis-ci.org/ianatha/ledgerex.svg?branch=master)](https://travis-ci.org/ianatha/ledgerex)
[![Coverage Status](https://coveralls.io/repos/github/ianatha/ledgerex/badge.svg?branch=master)](https://coveralls.io/github/ianatha/ledgerex?branch=master)

A parser for [Ledger](https://www.ledger-cli.org/3.0/doc/ledger3.html) accounting files written in Elixir.

_Caveat Emptor_: It doesn't support the full range of ledger's capabilities.
It's just the bare minimum I needed to parse my ~10 years worth of ledger files.

Pull requests more than welcome. Be nice.

## Example

```elixir
txt = """
2019/01/02 Hello AMEX
  Liabilities:AMEX       $2000.00
  Income                 $-2000.00 = $0

2019/01/02 Another AMEX
  Liabilities:AMEX       $4000.00
  Income
"""

# Load and parse the date
res = Ledger.Parsers.Ledger.parse(txt)

# Re-create the ledger file
Enum.each(res, fn x ->
  IO.puts(Ledger.Entry.to_string(x))
end)

Ledger.balance(txt)
```

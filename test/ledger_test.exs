defmodule LedgerTest do
  use ExUnit.Case
  doctest Ledger

  test "simple transaction" do
    txt = """
    2019/02/26
      Liabitilies:AMEX
      Transfer:AMEX			$-1,950.00
    """

    assert Ledger.Parsers.Ledger.parse(txt) == [
             %Ledger.Entry{
               date_alternative: nil,
               payee: nil,
               status: nil,
               tags: [],
               date: ~D[2019-02-26],
               entries: [
                 [account_name: "Liabitilies:AMEX"],
                 [account_name: "Transfer:AMEX", amount: ["$", "-1,950.00"]]
               ]
             }
           ]
  end

  test "simple transaction in unknown currency" do
    txt = """
    2019/02/26
      Liabitilies:AMEX
      Transfer:AMEX			ABCd -1,950.00
    """

    assert Ledger.Parsers.Ledger.parse(txt) == [
             %Ledger.Entry{
               date_alternative: nil,
               payee: nil,
               status: nil,
               tags: [],
               date: ~D[2019-02-26],
               entries: [
                 [account_name: "Liabitilies:AMEX"],
                 [account_name: "Transfer:AMEX", amount: ["ABCd", "-1,950.00"]]
               ]
             }
           ]
  end

  test "simple wrong transaction (with only one space after account name instead of two-or-more)" do
    txt = """
    2019/02/26
      Liabitilies:AMEX
      Transfer:AMEX $-1,950.00
    """

    refute Ledger.Parsers.Ledger.parse(txt) == [
             %Ledger.Entry{
               date_alternative: nil,
               payee: nil,
               status: nil,
               tags: [],
               date: ~D[2019-02-26],
               entries: [
                 [account_name: "Liabitilies:AMEX"],
                 [account_name: "Transfer:AMEX", amount: ["$", "-1,950.00"]]
               ]
             }
           ]
  end


  test "simple transaction in EUR" do
    txt = """
    2019/02/26 Something in EUR
      Liabitilies:AMEX
      Transfer:AMEX			EUR -1,950.00
    """

    assert Ledger.Parsers.Ledger.parse(txt) == [
             %Ledger.Entry{
               date_alternative: nil,
               payee: "Something in EUR",
               status: nil,
               tags: [],
               date: ~D[2019-02-26],
               entries: [
                 [account_name: "Liabitilies:AMEX"],
                 [account_name: "Transfer:AMEX", amount: ["EUR", "-1,950.00"]]
               ]
             }
           ]
  end

  test "simple transaction with balance assertion" do
    txt = """
    2019/02/26 Hello
      Liabilities:AMEX       $2000.00
      Income                 $-2000.00 = $0
    """

    assert Ledger.Parsers.Ledger.parse(txt) == [
             %Ledger.Entry{
               date: ~D[2019-02-26],
               date_alternative: nil,
               entries: [
                 [account_name: "Liabilities:AMEX", amount: ["$", "2000.00"]],
                 [
                   account_name: "Income",
                   amount: ["$", "-2000.00"],
                   balance_assertion: ["$", "0"]
                 ]
               ],
               payee: "Hello",
               status: nil,
               tags: []
             }
           ]
  end

  test "accounts with whitespace" do
    txt = """
    2019/02/26 Hello
      ; k1: v1 and whitepsace
      ; k2: v2
      Liabilities:AMEX Or Something       $2000.00
      Income:1\t      $-1000.00
      Income:2\t      $-1000.00
    """

    assert Ledger.Parsers.Ledger.parse(txt) == [
             %Ledger.Entry{
               date: ~D[2019-02-26],
               date_alternative: nil,
               entries: [
                 [account_name: "Liabilities:AMEX Or Something", amount: ["$", "2000.00"]],
                 [account_name: "Income:1", amount: ["$", "-1000.00"]],
                 [account_name: "Income:2", amount: ["$", "-1000.00"]]
               ],
               payee: "Hello",
               status: nil,
               tags: [["k1", "v1 and whitepsace"], ["k2", "v2"]]
             }
           ]
  end

  test "real entry" do
    txt = """
    2019/02/03=2019/02/01 * GOOGLE *GSUITE_TEST.COM
           ; trans_id: 20190203 705357 532 201,902,034,507
           ; trans_type: Debit
           ; ref_num: 564650848
           ; trans_cat: Entertainment
           ; type: Credit Card
           ; balance: $10,336.72
           ; sig: o67cDEwo7q0NTETkkjt7Ow==
           ; imported: 2019-11-10 03:33:31.870056Z
           ; star_prefix: GOOGLE
           Liabilities:MC                  $-5.32
           Expenses:Consulting:GSuite
    """

    assert Ledger.Parsers.Ledger.parse(txt) == [
             %Ledger.Entry{
               date: ~D[2019-02-03],
               date_alternative: ~D[2019-02-01],
               entries: [
                 [account_name: "Liabilities:MC", amount: ["$", "-5.32"]],
                 [account_name: "Expenses:Consulting:GSuite"]
               ],
               payee: "GOOGLE *GSUITE_TEST.COM",
               status: "*",
               tags: [
                 ["trans_id", "20190203 705357 532 201,902,034,507"],
                 ["trans_type", "Debit"],
                 ["ref_num", "564650848"],
                 ["trans_cat", "Entertainment"],
                 ["type", "Credit Card"],
                 ["balance", "$10,336.72"],
                 ["sig", "o67cDEwo7q0NTETkkjt7Ow=="],
                 ["imported", "2019-11-10 03:33:31.870056Z"],
                 ["star_prefix", "GOOGLE"]
               ]
             }
           ]
  end

  test "get currencies of an entry" do
    txt = """
    2019/02/26
      Liabitilies:AMEX        USD 2000
      Transfer:AMEX			EUR -1,950.00
    """

    [entry] = Ledger.Parsers.Ledger.parse(txt)
    assert Ledger.Entry.currencies(entry) == ["USD", "EUR"]
  end

  test "balancing of an entry" do
    txt = """
    2019/02/26
      Liabitilies:AMEX        USD 2000
      Transfer:AMEX			EUR -1,950.00
    """

    [entry] = Ledger.Parsers.Ledger.parse(txt)
    assert Ledger.Entry.balance(entry) == [{:"Liabitilies:AMEX  USD", "2000"}, {:"Transfer:AMEX  EUR", "-1950.00"}]
  end

  test "balancing-list of an a set of entries" do
    txt = """
    2019/02/26
      Liabitilies:AMEX        USD 2
      Transfer:AMEX			EUR -1

    2019/02/26
      Liabitilies:AMEX        USD 2
      Transfer:AMEX			EUR -1
    """

    entries = Ledger.Parsers.Ledger.parse(txt)
    assert Ledger.balance_list(entries) == ["Liabitilies:AMEX  USD": "4", "Transfer:AMEX  EUR": "-2"]
  end

  test "balancing of an a set of entries" do
    txt = """
    2019/02/26
      Liabitilies:AMEX        USD 2
      Transfer:AMEX			EUR -1

    2019/02/26
      Liabitilies:AMEX        USD 2
      Transfer:AMEX			EUR -1
    """

    entries = Ledger.Parsers.Ledger.parse(txt)
    assert Ledger.balance(entries) ==
    """
    Liabitilies:AMEX  USD 4
    Transfer:AMEX  EUR -2
    """
  end

  test "another balancing of an a set of entries" do
    txt = """
    2019/02/26
      Liabitilies:AMEX        USD 2
      Transfer:AMEX			EUR -1
      Expenses:Something			$-1

    2019/02/26
      Liabitilies:AMEX        USD 2
      Transfer:AMEX			EUR -1
    """

    entries = Ledger.Parsers.Ledger.parse(txt)
    assert Ledger.balance(entries) ==
    """
    Expenses:Something  $ -1
    Liabitilies:AMEX  USD 4
    Transfer:AMEX  EUR -2
    """
  end
end

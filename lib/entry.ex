defmodule Ledger.Entry do
  @moduledoc false

  defstruct date: nil,
            date_alternative: nil,
            status: nil,
            payee: nil,
            tags: [],
            entries: []

  @line_length 95

  def amount_to_str([cur, amt]) do
    case cur do
      "$" -> "#{cur}#{amt}"
      _ -> "#{cur} #{amt}"
    end
  end

  defp items_to_string(items, indent) do
    items
    |> Enum.map(fn
      [{:account_name, account}, {:amount, amount}, [tag_k, tag_v]] ->
        pre = "#{indent}#{account}"

        padded_amount =
          amount |> amount_to_str |> String.pad_leading(@line_length - String.length(pre))

        "#{pre}#{padded_amount} ; #{tag_k}: #{tag_v}"

      [account_name: account, amount: amount, balance_assertion: balance_assertion] ->
        pre = "#{indent}#{account}"

        amount_with_assert =
          (amount |> amount_to_str) <> " = " <> (balance_assertion |> amount_to_str)

        padded_amount =
          amount_with_assert |> String.pad_leading(@line_length - String.length(pre))

        "#{pre}#{padded_amount}"

      [account_name: account, amount: amount] ->
        pre = "#{indent}#{account}"

        padded_amount =
          amount |> amount_to_str |> String.pad_leading(@line_length - String.length(pre))

        "#{pre}#{padded_amount}"

      [account_name: account, balance_assertion: balance_assertion] ->
        pre = "#{indent}#{account}"

        padded_assert =
          (" = " <> (balance_assertion |> amount_to_str))
          |> String.pad_leading(@line_length - String.length(pre))

        "#{pre}#{padded_assert}"

      [account_name: account] ->
        "#{indent}#{account}"
    end)
    |> Enum.join("\n")
  end

  defp tags_to_string(tags, indent, joiner \\ "\n") do
    tags
    |> Enum.map(fn [k, v] ->
      "#{indent}; #{k}: #{v}"
    end)
    |> Enum.join(joiner)
  end

  def to_string(r) do
    alt_date =
      if r.date_alternative != nil do
        "#{r.date}=#{r.date_alternative}"
      else
        "#{r.date}"
      end

    status =
      if r.status != nil do
        "#{r.status}"
      else
        ""
      end

    (([
        [alt_date, status, r.payee]
        |> Enum.filter(fn x -> x != nil and String.length(x) > 0 end)
        |> Enum.join(" "),
        "#{tags_to_string(r.tags, "    ")}",
        "#{items_to_string(r.entries, "    ")}"
      ]
      |> Enum.filter(fn x -> String.length(x) != 0 end)) ++ [""])
    |> Enum.join("\n")
  end

  @doc """
  Adds missing amounts if not all are filled.
  """
  def update_amounts(entry) do
    nr_without_amounts =
      Enum.reduce(entry.entries, 0, fn e, acc ->
        if Keyword.get(e, :amount), do: acc, else: acc + 1
      end)

    currencies = currencies(entry)

    if nr_without_amounts > 1,
      do: raise("More than one entry has no amount: #{Kernel.inspect(entry)}")

    if nr_without_amounts == 1 and Enum.count(currencies) > 1,
      do: raise("More than one currency not allowed: #{Kernel.inspect(entry)}")

    currency = Enum.at(currencies, 0)

    missing_amount =
      Enum.reduce(entry.entries, 0, fn e, acc ->
        [_currency, amount_str] = Keyword.get(e, :amount, ["", "0"])
        amount = Decimal.new(normalize_number(amount_str))
        acc + amount
      end)

    entries =
      if missing_amount != 0 do
        idx = Enum.find_index(entry.entries, fn e -> is_nil(Keyword.get(e, :amount)) end)
        e = Enum.at(entry.entries, idx)

        Enum.map(entry.entries, fn e ->
          if is_nil(Keyword.get(e, :amount)) do
            amount = [currency, Decimal.to_string(-missing_amount)]
            e ++ [amount: amount]
          else
            e
          end
        end)
      else
        entry.entries
      end

    Map.replace(entry, :entries, entries)
  end

  def currencies(entry) do
    Enum.reduce(entry.entries, [], fn e, acc ->
      [currency, _amount_str] = Keyword.get(e, :amount, [nil, "0"])
      if is_nil(currency), do: acc, else: acc ++ [currency]
    end)
  end

  @doc """
  Balances a single entry.
  """
  def balance(entry) when is_struct(entry) do
    Enum.reduce(entry.entries, [], fn x, acc ->
      account_name = Keyword.get(x, :account_name)
      [currency, amount] = Keyword.get(x, :amount)
      amount_num = Decimal.new(normalize_number(amount))
      Keyword.merge(acc, ["#{account_name}  #{currency}": Decimal.to_string(amount_num)], fn _k, v1, v2 ->
        v1_num = Decimal.new(normalize_number(v1))
        v2_num = Decimal.new(normalize_number(v2))
        Decimal.add(v1_num, v2_num)
        |> Decimal.to_string
      end)
    end)
  end


  defp normalize_number(num) do
    String.replace(num, ",", "")
  end
end

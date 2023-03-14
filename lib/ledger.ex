defmodule Ledger do
  @moduledoc false

  def balance(str) when is_binary(str) do
  end

  def balance(entries) when is_list(entries) do
    Enum.reduce(entries, [], fn entry, acc ->
      Keyword.merge(acc, Ledger.Entry.balance(entry), fn _k, v1, v2 ->
        v1 + v2
      end)
    end)
  end

  def accounts(entries) when is_list(entries) do
    Enum.reduce(entries, [], fn entry, acc ->
      Enum.reduce(entry.entries, acc, fn x, acc2 ->
        account_name = Keyword.get(x, :account_name)

        if Enum.member?(acc2, account_name) do
          acc
        else
          [account_name | acc2]
        end
      end)
    end)
    |> Enum.sort()
  end
end

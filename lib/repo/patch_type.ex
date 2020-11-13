defmodule ExAudit.Type.Patch do
  use Ecto.Type
  @strategy_types %{json: :map, binary: :binary}

  defp get_strategy_type(), do: Application.get_env(:ex_audit, :strategy) || :binary

  def cast(a), do: {:ok, a}

  def dump(map) do
    case get_strategy_type() do
      :json ->
        elm =
          map
          |> convert_map_to_json()

        {:ok, elm}

      :binary ->
        {:ok, :erlang.term_to_binary(map)}
    end
  end

  def load(data) do
    case get_strategy_type() do
      :json ->
        json = Morphix.atomorphiform!(data)
        {:ok, json}

      :binary ->
        {:ok, :erlang.binary_to_term(data)}
    end
  end

  def type, do: @strategy_types[get_strategy_type()]

  defp convert_map_to_json(patch) do
    patch
    |> Enum.map(&begin_convertion/1)
    |> Enum.into(%{})
  end

  defp begin_convertion({key, value})
       when is_tuple(value),
       do: {key, do_the_convertion(value)}

  defp begin_convertion(elem), do: elem

  defp do_the_convertion(tuple) do
    Enum.map(0..(tuple_size(tuple) - 1), fn x ->
      tuple
      |> elem(x)
      |> case do
        x when is_tuple(x) ->
          do_the_convertion(x)

        x when is_map(x) ->
          if !Map.has_key?(x, :__struct__),
            do: convert_map_to_json(x),
            else: x

        x ->
          x
      end
    end)
    |> Enum.chunk_every(3)
    |> Enum.map(&apply_conversion/1)
    |> Enum.at(0)
  end

  defp apply_conversion([:not_changed]), do: :not_changed
  defp apply_conversion([:added, elem]), do: %{added: elem}
  defp apply_conversion([:removed, elem]), do: %{removed: elem}

  defp apply_conversion([:changed, changes]) when is_map(changes),
    do: %{changed: convert_map_to_json(changes)}

  defp apply_conversion([:primitive_change, before_elem, after_elem]) do
    %{primitive_change: %{before: before_elem, after: after_elem}}
  end

  defp apply_conversion(elem), do: elem
end

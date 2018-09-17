defmodule ExAudit.Type.Patch do
  @behaviour Ecto.Type

  def cast(a), do: {:ok, a}

  def dump(map) do
    elm =
      map
      |> convert_map_to_json()
      |> Poison.encode!()

    {:ok, elm}
  end

  def load(json) do
    elm =
      json
      |> Poison.decode!()
      |> convert_json_to_map()

    {:ok, elm}
  end

  def type, do: :map

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
  end

  def convert_json_to_map(elem) do
    elem
    |> convertion_to_atoms()
    |> Enum.into(%{})
  end

  defp convertion_to_atoms(x) when is_map(x) do
    Enum.map(x, fn
      {key, value} -> {String.to_atom(key), convertion_to_atoms(value)}
    end)
  end

  defp convertion_to_atoms(x) when is_list(x) do
    x
    |> Enum.chunk_every(3)
    |> Enum.map(&apply_conversion/1)
    |> Enum.at(0)
  end

  def apply_conversion(["not_changed"]), do: :not_changed
  def apply_conversion(["added", elem]), do: {:added, elem}
  def apply_conversion(["removed", elem]), do: {:removed, elem}

  def apply_conversion(["changed", changes]) when is_map(changes),
    do: {:changed, convert_json_to_map(changes)}

  def apply_conversion(["changed", changes]) when is_list(changes),
    do: {:changed, convertion_to_atoms(changes)}

  def apply_conversion(["primitive_change", a, b]) do
    a = if is_list(a), do: List.to_tuple(a), else: a
    b = if is_list(b), do: List.to_tuple(b), else: b

    {:primitive_change, a, b}
  end
end

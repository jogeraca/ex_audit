defmodule ExAudit.Schema do
  def insert_all(module, adapter, schema_or_source, entries, opts)
      when is_binary(schema_or_source) do
    opts = augment_opts(opts)
    Ecto.Repo.Schema.insert_all(module, adapter, schema_or_source, entries, opts)
  end

  def insert_all(module, adapter, schema_or_source, entries, opts) do
    opts = augment_opts(opts)

    augment_transaction(module, fn ->
      result =
        Ecto.Repo.Schema.insert_all(
          module,
          adapter,
          schema_or_source,
          entries,
          Keyword.put(opts, :returning, true)
        )

      case result do
        {rows, changesets} when is_list(changesets) and rows > 0 ->
          Enum.each(changesets, fn changeset ->
            ExAudit.Tracking.track_change(
              module,
              adapter,
              :created,
              schema_or_source,
              changeset,
              opts
            )
          end)

        _ ->
          :ok
      end

      result
    end)
  end

  def insert(module, adapter, struct, opts) do
    opts = augment_opts(opts)

    augment_transaction(module, fn ->
      result = Ecto.Repo.Schema.insert(module, adapter, struct, opts)

      case result do
        {:ok, resulting_struct} ->
          ExAudit.Tracking.track_change(module, adapter, :created, struct, resulting_struct, opts)

        _ ->
          :ok
      end

      result
    end)
  end

  def update(module, adapter, struct, opts) do
    opts = augment_opts(opts)

    augment_transaction(module, fn ->
      result = Ecto.Repo.Schema.update(module, adapter, struct, opts)

      case result do
        {:ok, resulting_struct} ->
          ExAudit.Tracking.track_change(module, adapter, :updated, struct, resulting_struct, opts)

        _ ->
          :ok
      end

      result
    end)
  end

  def insert_or_update(module, adapter, changeset, opts) do
    # TODO!
    opts = augment_opts(opts)
    Ecto.Repo.Schema.insert_or_update(module, adapter, changeset, opts)
  end

  def delete(module, adapter, struct, opts) do
    opts = augment_opts(opts)

    augment_transaction(module, fn ->
      ExAudit.Tracking.track_assoc_deletion(module, adapter, struct, opts)
      result = Ecto.Repo.Schema.delete(module, adapter, struct, opts)

      case result do
        {:ok, resulting_struct} ->
          ExAudit.Tracking.track_change(module, adapter, :deleted, struct, resulting_struct, opts)

        _ ->
          :ok
      end

      result
    end)
  end

  def insert!(module, adapter, struct, opts) do
    opts = augment_opts(opts)

    augment_transaction(
      module,
      fn ->
        result = Ecto.Repo.Schema.insert!(module, adapter, struct, opts)
        ExAudit.Tracking.track_change(module, adapter, :created, struct, result, opts)
        result
      end,
      true
    )
  end

  def update!(module, adapter, struct, opts) do
    opts = augment_opts(opts)

    augment_transaction(
      module,
      fn ->
        result = Ecto.Repo.Schema.update!(module, adapter, struct, opts)
        ExAudit.Tracking.track_change(module, adapter, :updated, struct, result, opts)
        result
      end,
      true
    )
  end

  def insert_or_update!(module, adapter, changeset, opts) do
    # TODO
    opts = augment_opts(opts)
    Ecto.Repo.Schema.insert_or_update!(module, adapter, changeset, opts)
  end

  def delete!(module, adapter, struct, opts) do
    opts = augment_opts(opts)

    augment_transaction(
      module,
      fn ->
        ExAudit.Tracking.track_assoc_deletion(module, adapter, struct, opts)
        result = Ecto.Repo.Schema.delete!(module, adapter, struct, opts)
        ExAudit.Tracking.track_change(module, adapter, :deleted, struct, result, opts)
        result
      end,
      true
    )
  end

  # Cleans up the return value from repo.transaction
  def augment_transaction(repo, fun, bang \\ false) do
    multi =
      Ecto.Multi.new()
      |> Ecto.Multi.run(:main, __MODULE__, :run_in_multi, [fun, bang])

    case {repo.transaction(multi), bang} do
      {{:ok, %{main: value}}, false} -> {:ok, value}
      {{:ok, %{main: value}}, true} -> value
      {{:error, :main, error, _}, false} -> {:error, error}
      {{:error, :main, error, _}, true} -> raise error
    end
  end

  def run_in_multi(_multi, fun, bang) do
    case {fun.(), bang} do
      {{:ok, _} = ok, false} ->
        ok

      {{:error, _} = error, false} ->
        error

      {value, true} ->
        {:ok, value}

      # insert_all
      {{_, array} = value, false} when is_list(array) ->
        {:ok, value}

      # delete_all
      {value, false} when is_tuple(value) ->
        {:ok, value}
    end
  end

  # Gets the custom data from the ets store that stores it by PID, and adds
  # it to the list of custom data from the options list
  #
  # This is done so it works inside a transaction (which happens when ecto mutates assocs at the same time)

  def augment_opts(opts) do
    opts
    |> Keyword.put_new(:ex_audit_custom, [])
    |> Keyword.update(:ex_audit_custom, [], fn custom_fields ->
      case Process.whereis(ExAudit.CustomData) do
        nil -> []
        _ -> ExAudit.CustomData.get()
      end ++ custom_fields
    end)
  end
end

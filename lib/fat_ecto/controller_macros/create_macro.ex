defmodule FatEcto.CreateRecord do
  @moduledoc false
  @doc "Preprocess params before passing them to changeset"
  @callback pre_process_params_for_create_method(params :: map(), conn :: Plug.Conn.t()) :: map()

  @doc "Preprocess changeset before inserting record"
  @callback pre_process_changeset_for_create_method(
              changeset :: Ecto.Changeset.t(),
              params :: map(),
              conn :: Plug.Conn.t()
            ) :: Ecto.Changeset.t()

  @doc "Perform any action on new record after record is created"
  @callback post_create_hook_for_create_method(record :: struct(), params :: map(), conn :: Plug.Conn.t()) ::
              term()

  @doc "Insert record and it takes changeset and repo name as an argument"
  @callback insert_record_for_create_method(changeset :: Ecto.Changeset.t(), repo :: module()) ::
              {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  defmacro __using__(options) do
    quote location: :keep do
      alias FatEcto.MacrosHelper
      @repo unquote(options)[:repo]
      @preloads unquote(options)[:preloads] || []
      @behaviour FatEcto.CreateRecord

      if !@repo do
        raise "please define repo when using create record"
      end

      @schema unquote(options)[:schema]

      if !@schema do
        raise "please define schema when using create record"
      end

      @wrapper unquote(options)[:wrapper]
      @custom_changeset unquote(options)[:custom_changeset]
      if @wrapper in [nil, ""] do
        def create(conn, %{} = params) do
          _craete(conn, params)
        end
      else
        def create(conn, %{@wrapper => params}) do
          _craete(conn, params)
        end
      end

      defp _craete(conn, params) do
        params = pre_process_params_for_create_method(params, conn)
        changeset = build_insert_changeset(@custom_changeset, params)
        changeset = pre_process_changeset_for_create_method(changeset, params, conn)

        with {:ok, record} <- insert_record_for_create_method(changeset, @repo) do
          record = MacrosHelper.preload_record(record, @repo, @preloads)
          post_create_hook_for_create_method(record, params, conn)
          render_record(conn, record, [status_to_put: :created] ++ unquote(options))
        end
      end

      def insert_record_for_create_method(changeset, repo) do
        repo.insert(changeset)
      end

      def pre_process_params_for_create_method(params, _conn) do
        params
      end

      def pre_process_changeset_for_create_method(changeset, _params, _conn) do
        changeset
      end

      def post_create_hook_for_create_method(_record, _params, _conn) do
        "Override if needed"
      end

      defp build_insert_changeset(cs, params) when is_nil(cs), do: @schema.changeset(struct(@schema), params)

      defp build_insert_changeset(cs, params) when is_function(cs, 2) do
        cs.(struct(@schema), params)
      end

      defp build_insert_changeset(cs, _params), do: cs

      defoverridable FatEcto.CreateRecord
    end
  end
end

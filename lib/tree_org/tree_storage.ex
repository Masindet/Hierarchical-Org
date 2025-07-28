defmodule TreeOrg.TreeStorage do
  @moduledoc """
  ETS-based storage for the organizational tree structure.
  """

  @table_name :org_tree_storage

  require Phoenix.PubSub
  require Logger

  def init do
    # ETS table should be created by TreeStorageServer
    # This is a no-op now, just ensure the table exists
    case :ets.info(@table_name) do
      :undefined ->
        # Table doesn't exist, TreeStorageServer should be started
        :error
      _ ->
        :ok
    end
  end

  def get_tree do
    if :ets.info(@table_name) == :undefined do
      Logger.info("[TreeStorage] get_tree: ETS table undefined")
      nil
    else
      case :ets.lookup(@table_name, :tree) do
        [{:tree, tree}] ->
          Logger.info("[TreeStorage] get_tree: returning tree: #{inspect(tree)}")
          tree
        [] ->
          Logger.info("[TreeStorage] get_tree: no tree found")
          nil
      end
    end
  end

  def update_tree(tree) do
    Logger.info("[TreeStorage] update_tree: updating tree: #{inspect(tree)}")
    :ets.insert(@table_name, {:tree, tree})
    increment_version()
    Logger.info("[TreeStorage] update_tree: broadcasting :tree_updated")
    Phoenix.PubSub.broadcast(TreeOrg.PubSub, "tree_updates", :tree_updated)
    tree
  end

  def get_version do
    case :ets.lookup(@table_name, :version) do
      [{:version, version}] -> version
      [] -> 1
    end
  end

  def increment_version do
    new_version = get_version() + 1
    :ets.insert(@table_name, {:version, new_version})
    new_version
  end

  def reset do
    if :ets.info(@table_name) != :undefined do
      :ets.delete_all_objects(@table_name)
    end
    init()
  end
end

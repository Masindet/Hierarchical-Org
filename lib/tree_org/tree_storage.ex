defmodule TreeOrg.TreeStorage do
  @moduledoc """
  ETS-based storage for the organizational tree structure.
  """

  @table_name :org_tree_storage

  alias TreeOrg.TreeNode
  require Phoenix.PubSub
  require Logger

  def get_root_node do
    ensure_table_exists()
    case :ets.lookup(@table_name, :root_id) do
      [{:root_id, root_id}] ->
        Logger.info("TreeStorage: Found root_id: #{root_id}")
        get_node(root_id)
      [] ->
        Logger.warning("TreeStorage: No root_id found in ETS")
        nil
    end
  end

  def get_node(node_id) do
    ensure_table_exists()
    Logger.info("TreeStorage: Getting node: #{node_id}")

    # Log ETS entry count for debugging (not full details)
    all_entries = :ets.tab2list(@table_name)
    entry_count = length(all_entries)
    Logger.info("TreeStorage: ETS has #{entry_count} entries")

    case :ets.lookup(@table_name, node_id) do
      [{_node_id, node}] ->
        Logger.info("TreeStorage: Found node: #{inspect(TreeNode.safe_inspect(node))}")
        node
      [] ->
        Logger.error("TreeStorage: Node #{node_id} not found in ETS")
        Logger.error("TreeStorage: Available node IDs: #{inspect(Enum.map(all_entries, fn {k, _} -> k end))}")

        # Check if node exists in database
        case check_node_in_database(node_id) do
          {:ok, db_node} ->
            Logger.warning("TreeStorage: Node #{node_id} found in database but not in ETS - syncing")
            :ets.insert(@table_name, {node_id, db_node})
            db_node
          {:error, :not_found} ->
            Logger.error("TreeStorage: Node #{node_id} not found in database either")
            nil
        end
    end
  end

  # Helper function to check if a node exists in the database
  defp check_node_in_database(node_id) do
    alias TreeOrg.Repo
    alias TreeOrg.TreeNode

    case Repo.get(TreeNode, node_id) do
      nil -> {:error, :not_found}
      node -> {:ok, node}
    end
  end

  def get_children(node_id) do
    ensure_table_exists()
    children = :ets.select(@table_name, [{{:_, :'$1'}, [{:'==', {:map_get, :parent_id, :'$1'}, node_id}], [:'$1']}])
    # Only log if there are children to avoid spam
    if length(children) > 0 do
      Logger.info("TreeStorage: Found #{length(children)} children for node #{node_id}: #{inspect(children)}")
    end
    children
  end

  def add_node(name, parent_id) do
    ensure_table_exists()
    alias TreeOrg.Repo
    alias TreeOrg.TreeNode

    Logger.info("TreeStorage: Adding node: name=#{name}, parent_id=#{inspect(parent_id)}")

    changeset = TreeNode.changeset(%TreeNode{}, %{name: name, parent_id: parent_id})

    case Repo.insert(changeset) do
      {:ok, node} ->
        Logger.info("TreeStorage: Successfully inserted node into database: #{inspect(TreeNode.safe_inspect(node))}")

        # Force a complete refresh of ETS from database to ensure consistency
        refresh_ets_from_database()

        # Broadcast the update to all LiveViews
        broadcast_tree_update()

        {:ok, node}
      {:error, changeset} ->
        Logger.error("TreeStorage: Failed to insert node: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  def update_node(node_id, attrs) do
    ensure_table_exists()
    alias TreeOrg.Repo
    alias TreeOrg.TreeNode

    Logger.info("TreeStorage: Updating node #{node_id} with attrs: #{inspect(attrs)}")

    # Get the node from the database, not ETS
    case Repo.get(TreeNode, node_id) do
      nil ->
        Logger.error("TreeStorage: Node #{node_id} not found in database")
        {:error, :not_found}
      node ->
        Logger.info("TreeStorage: Found node in database: #{inspect(TreeNode.safe_inspect(node))}")
        changeset = TreeNode.changeset(node, attrs)

        case Repo.update(changeset) do
          {:ok, updated_node} ->
            Logger.info("TreeStorage: Successfully updated node #{node_id} in database: #{inspect(TreeNode.safe_inspect(updated_node))}")

            # Force a complete refresh of ETS from database to ensure consistency
            refresh_ets_from_database()

            # Broadcast the update to all LiveViews
            broadcast_tree_update()

            {:ok, updated_node}
          {:error, changeset} ->
            Logger.error("TreeStorage: Failed to update node #{node_id}: #{inspect(changeset.errors)}")
            {:error, changeset}
        end
    end
  end

  def delete_node(node_id) do
    ensure_table_exists()
    alias TreeOrg.Repo
    alias TreeOrg.TreeNode

    Logger.info("TreeStorage: Starting deletion of node #{node_id}")

    # Get all children and delete them recursively first
    children = get_children_without_ensure(node_id)
    Logger.info("TreeStorage: Found #{length(children)} children to delete first")

    Enum.each(children, fn child ->
      Logger.info("TreeStorage: Recursively deleting child: #{inspect(child)}")
      delete_node(child.id)
    end)

    # Get the node from the database, not ETS
    case Repo.get(TreeNode, node_id) do
      nil ->
        Logger.warning("TreeStorage: Node #{node_id} not found in database, removing from ETS")
        :ets.delete(@table_name, node_id)
        # Only refresh and broadcast once at the end of the entire deletion process
        :ok
      node ->
        Logger.info("TreeStorage: Deleting node #{node_id} from database: #{inspect(TreeNode.safe_inspect(node))}")
        case Repo.delete(node) do
          {:ok, deleted_node} ->
            Logger.info("TreeStorage: Successfully deleted node #{node_id} from database: #{inspect(TreeNode.safe_inspect(deleted_node))}")
            # Only refresh and broadcast once at the end of the entire deletion process
            :ok
          {:error, changeset} ->
            Logger.error("TreeStorage: Failed to delete node #{node_id}: #{inspect(changeset.errors)}")
            {:error, changeset}
        end
    end
  end

  # Optimized version of get_children that doesn't call ensure_table_exists
  defp get_children_without_ensure(node_id) do
    children = :ets.select(@table_name, [{{:_, :'$1'}, [{:'==', {:map_get, :parent_id, :'$1'}, node_id}], [:'$1']}])
    # Only log if there are children to avoid spam during recursive deletion
    if length(children) > 0 do
      Logger.info("TreeStorage: Found #{length(children)} children for node #{node_id} during deletion")
    end
    children
  end

  # Public function to delete a node and handle the final refresh/broadcast
  def delete_node_and_refresh(node_id) do
    Logger.info("TreeStorage: Starting delete_node_and_refresh for node #{node_id}")
    result = delete_node(node_id)

    # Refresh and broadcast only once after the entire deletion process
    refresh_ets_from_database()
    broadcast_tree_update()

    result
  end

  # Helper function to refresh ETS from database (internal use)
  defp refresh_ets_from_database do
    alias TreeOrg.Repo
    alias TreeOrg.TreeNode

    Logger.info("TreeStorage: Refreshing ETS from database")

    # Clear existing ETS data
    :ets.delete_all_objects(@table_name)

    # Load all nodes from database
    nodes = Repo.all(TreeNode)
    Logger.info("TreeStorage: Loading #{length(nodes)} nodes into ETS")

    # Log only essential node info to avoid massive output
    node_summary = Enum.map(nodes, fn node -> %{id: node.id, name: node.name, parent_id: node.parent_id} end)
    Logger.info("TreeStorage: Node summary: #{inspect(node_summary)}")

    Enum.each(nodes, fn node ->
      :ets.insert(@table_name, {node.id, node})
    end)

    # Set root node if exists
    case Enum.find(nodes, fn node -> is_nil(node.parent_id) end) do
      nil ->
        Logger.info("TreeStorage: No root node found")
        :ok
      root_node ->
        Logger.info("TreeStorage: Setting root node to #{root_node.id}")
        :ets.insert(@table_name, {:root_id, root_node.id})
    end

    # Log final ETS state summary
    final_entries = :ets.tab2list(@table_name)
    entry_count = length(final_entries)
    Logger.info("TreeStorage: Final ETS state - #{entry_count} entries loaded")

    # Only log detailed state if there are few entries (for debugging)
    if entry_count <= 10 do
      Logger.info("TreeStorage: ETS entries: #{inspect(final_entries)}")
    end
  end

  # Helper function to initialize/load data from database to ETS
  def load_from_database do
    case :ets.info(@table_name) do
      :undefined ->
        Logger.info("TreeStorage: Creating new ETS table")
        :ets.new(@table_name, [:set, :public, :named_table])
      _ ->
        Logger.info("TreeStorage: ETS table already exists")
        :ok
    end

    refresh_ets_from_database()
  end

  # Helper function to ensure ETS table exists
  def ensure_table_exists do
    case :ets.info(@table_name) do
      :undefined ->
        Logger.info("TreeStorage: Creating ETS table")
        :ets.new(@table_name, [:set, :public, :named_table])
        refresh_ets_from_database()
      _ ->
        # Don't log this every time to avoid spam
        :ok
    end
  end

  # Centralized broadcast function
  defp broadcast_tree_update do
    Logger.info("TreeStorage: Broadcasting tree update")
    Phoenix.PubSub.broadcast(TreeOrg.PubSub, "tree_updates", :tree_updated)
  end

  # Public function to refresh ETS from database (for external calls)
  def refresh_from_database do
    Logger.info("TreeStorage: External refresh_from_database called")
    load_from_database()
    # Small delay to ensure database consistency
    Process.sleep(10)
    broadcast_tree_update()
  end

  # Public function to refresh ETS from database without broadcasting (for LiveView use)
  def refresh_from_database_silent do
    Logger.info("TreeStorage: Silent refresh_from_database called")
    load_from_database()
    # Small delay to ensure database consistency
    Process.sleep(10)
  end

  # Public function to force refresh the entire tree structure
  def force_refresh_tree do
    Logger.info("TreeStorage: Force refresh tree called")

    # Complete refresh from database
    refresh_ets_from_database()

    # Small delay to ensure database consistency
    Process.sleep(10)

    # Broadcast update to all LiveViews
    broadcast_tree_update()

    Logger.info("TreeStorage: Force refresh completed")
    :ok
  end
end

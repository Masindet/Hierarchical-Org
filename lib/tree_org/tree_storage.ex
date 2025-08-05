defmodule TreeOrg.TreeStorage do
  @moduledoc """
  ETS-based storage for the organizational tree structure.
  """

  @table_name :org_tree_storage

  require Phoenix.PubSub

  def get_root_node do
    case :ets.lookup(@table_name, :root_id) do
      [{:root_id, root_id}] -> get_node(root_id)
      [] -> nil
    end
  end

  def get_node(node_id) do
    case :ets.lookup(@table_name, node_id) do
      [{_node_id, node}] -> node
      [] -> nil
    end
  end

  def get_children(node_id) do
    :ets.select(@table_name, [{{:_, :'$1'}, [{:'==', {:map_get, :parent_id, :'$1'}, node_id}], [:'$1']}])
  end

  def add_node(name, parent_id) do
    alias TreeOrg.Repo
    alias TreeOrg.TreeNode

    changeset = TreeNode.changeset(%TreeNode{}, %{name: name, parent_id: parent_id})

    case Repo.insert(changeset) do
      {:ok, node} ->
        :ets.insert(@table_name, {node.id, node})
        Phoenix.PubSub.broadcast(TreeOrg.PubSub, "tree_updates", :tree_updated)
        {:ok, node}
      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update_node(node_id, attrs) do
    alias TreeOrg.Repo
    alias TreeOrg.TreeNode

    node = get_node(node_id)
    changeset = TreeNode.changeset(node, attrs)

    case Repo.update(changeset) do
      {:ok, updated_node} ->
        :ets.insert(@table_name, {updated_node.id, updated_node})
        Phoenix.PubSub.broadcast(TreeOrg.PubSub, "tree_updates", :tree_updated)
        {:ok, updated_node}
      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def delete_node(node_id) do
    children = get_children(node_id)
    Enum.each(children, fn child ->
      delete_node(child.id)
    end)

    alias TreeOrg.Repo

    if node = get_node(node_id) do
      case Repo.delete(node) do
        {:ok, _} ->
          :ets.delete(@table_name, node_id)
          Phoenix.PubSub.broadcast(TreeOrg.PubSub, "tree_updates", :tree_updated)
          :ok
        {:error, changeset} ->
          {:error, changeset}
      end
    else
      # Node not found, probably already deleted recursively.
      :ok
    end
  end
end
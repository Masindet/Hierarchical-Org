defmodule TreeOrg.TreeStorageServer do
  use GenServer

  @table_name :org_tree_storage

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    # Create ETS table
    :ets.new(@table_name, [:set, :public, :named_table])

    # Load tree from database
    load_tree_from_database()

    {:ok, %{}}
  end

  defp load_tree_from_database do
    alias TreeOrg.Repo
    alias TreeOrg.TreeNode

    # Fetch all tree nodes from database
    nodes = Repo.all(TreeNode)

    # Find the root node (the one with no parent)
    root_node = Enum.find(nodes, &is_nil(&1.parent_id))

    # Insert each node into the ETS table
    Enum.each(nodes, fn node ->
      :ets.insert(@table_name, {node.id, node})
    end)

    # Store the ID of the root node
    if root_node do
      :ets.insert(@table_name, {:root_id, root_node.id})
    end
  end
end

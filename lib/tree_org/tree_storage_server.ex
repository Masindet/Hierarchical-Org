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
    tree = load_tree_from_database()

    :ets.insert(@table_name, {:tree, tree})
    :ets.insert(@table_name, {:version, 1})

    {:ok, %{}}
  end

  defp load_tree_from_database do
    alias TreeOrg.Repo
    alias TreeOrg.TreeNode

    # Fetch all tree nodes from database
    nodes = Repo.all(TreeNode)

    # Build tree structure from nodes
    case TreeNode.build_tree_from_nodes(nodes) do
      [root_node] -> root_node
      [] -> nil  # Return nil instead of "Empty" node
      _ -> %{id: nil, name: "Multiple Roots", children: []}
    end
  end
end

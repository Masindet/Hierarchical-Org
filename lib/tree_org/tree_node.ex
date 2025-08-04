defmodule TreeOrg.TreeNode do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tree_nodes" do
    field :name, :string

    belongs_to :parent, TreeOrg.TreeNode
    has_many :children, TreeOrg.TreeNode, foreign_key: :parent_id

    timestamps()
  end

  def changeset(tree_node, attrs) do
    tree_node
    |> cast(attrs, [:name, :parent_id])
    |> validate_required([:name])
  end

  def build_tree_from_nodes(nodes) do
    # Group nodes by parent_id for efficient lookup
    nodes_by_parent = Enum.group_by(nodes, &(&1.parent_id))

    # Get root nodes (those with parent_id = nil)
    root_nodes = nodes_by_parent[nil] || []

    # Build tree recursively
    Enum.map(root_nodes, fn node ->
      build_node_with_children(node, nodes_by_parent)
    end)
  end

  defp build_node_with_children(node, nodes_by_parent) do
    children = nodes_by_parent[node.id] || []

    %{
      id: node.id,
      name: node.name,
      parent_id: node.parent_id,
      children: Enum.map(children, fn child ->
        build_node_with_children(child, nodes_by_parent)
      end)
    }
  end
end

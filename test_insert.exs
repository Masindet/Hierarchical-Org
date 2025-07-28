# Test script to verify insert_node function
defmodule TestInsert do
  def insert_node_recursive(%{name: name} = node, target_name, new_node) when name == target_name do
    # Found the target node, add the new node as a child
    IO.inspect("MATCH FOUND: #{name}", label: "Target Match")
    updated_node = %{node | children: (node.children || []) ++ [new_node]}
    IO.inspect(updated_node, label: "Node After Adding Child")
    updated_node
  end

  def insert_node_recursive(%{children: children} = node, target_name, new_node) when is_list(children) do
    # Recursively search through children
    IO.inspect("Searching in node: #{node.name}", label: "Current Node")
    updated_children = Enum.map(children, fn child ->
      insert_node_recursive(child, target_name, new_node)
    end)
    %{node | children: updated_children}
  end

  def insert_node_recursive(node, target_name, _new_node) do
    # Leaf node or node without children - return as is
    IO.inspect("Leaf node: #{node.name}, looking for: #{target_name}", label: "Leaf Node")
    node
  end

  def test_insert do
    tree = %{
      id: "ceo-1",
      name: "CEO",
      children: [
        %{id: "cto-1", name: "CTO", children: []},
        %{id: "cfo-1", name: "CFO", children: []}
      ]
    }

    new_node = %{id: "dev-1", name: "Developer - John", children: []}

    IO.inspect(tree, label: "Original Tree")
    updated_tree = insert_node_recursive(tree, "CTO", new_node)
    IO.inspect(updated_tree, label: "Updated Tree")

    # Check if the node was actually added
    cto_node = Enum.find(updated_tree.children, fn child -> child.name == "CTO" end)
    IO.inspect(cto_node, label: "CTO Node After Update")
    
    if length(cto_node.children) > 0 do
      IO.puts("SUCCESS: Node was added!")
    else
      IO.puts("FAILURE: Node was not added!")
    end
  end
end

TestInsert.test_insert()

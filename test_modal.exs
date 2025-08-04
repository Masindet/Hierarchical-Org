# Test script to verify modal functionality
defmodule TestModal do
  alias TreeOrg.TreeStorage

  def test_modal_functionality do
    # Clear existing tree
    TreeStorage.update_tree(nil)

    # Create a test tree with multiple levels
    tree = %{
      id: "ceo-1",
      name: "CEO - John Smith",
      children: [
        %{id: "cto-1", name: "CTO - Jane Doe", children: [
          %{id: "dev-1", name: "Developer - Alice Johnson", children: []},
          %{id: "dev-2", name: "Developer - Bob Wilson", children: []},
          %{id: "dev-3", name: "Developer - Carol Brown", children: []},
          %{id: "dev-4", name: "Developer - David Lee", children: []},
          %{id: "dev-5", name: "Developer - Eve Davis", children: []},
          %{id: "dev-6", name: "Developer - Frank Miller", children: []}
        ]},
        %{id: "cfo-1", name: "CFO - Mike Johnson", children: [
          %{id: "acc-1", name: "Accountant - Grace Taylor", children: []},
          %{id: "acc-2", name: "Accountant - Henry Adams", children: []}
        ]}
      ]
    }

    # Update the tree
    TreeStorage.update_tree(tree)

    # Get the updated tree
    updated_tree = TreeStorage.get_tree()

    IO.puts("=== Test Tree Created ===")
    IO.inspect(updated_tree, label: "Updated Tree")

    # Check if the CTO node has enough children to trigger grouping
    cto_node = find_node_by_id(updated_tree, "cto-1")
    if cto_node do
      IO.puts("CTO node children count: #{length(cto_node.children)}")
      if length(cto_node.children) > 3 do
        IO.puts("SUCCESS: CTO node has more than 3 children, should trigger grouping!")
      else
        IO.puts("INFO: CTO node has #{length(cto_node.children)} children")
      end
    end

    IO.puts("\n=== Modal Test Instructions ===")
    IO.puts("1. Open your browser and go to http://localhost:4000")
    IO.puts("2. You should see the organizational chart")
    IO.puts("3. Look for a green 'Team Members' group under the CTO")
    IO.puts("4. Click on the green group node")
    IO.puts("5. A modal should appear showing all the developers")
    IO.puts("6. The modal should have the same UI styling as the tree")
    IO.puts("7. You should be able to edit/delete members from the modal")
    IO.puts("8. Click the X or Close button to close the modal")
  end

  defp find_node_by_id(%{id: id} = node, target_id) when id == target_id, do: node
  defp find_node_by_id(%{children: children}, target_id) when is_list(children) do
    Enum.find_value(children, fn child ->
      find_node_by_id(child, target_id)
    end)
  end
  defp find_node_by_id(_, _), do: nil
end

TestModal.test_modal_functionality()

defmodule TreeOrgWeb.TreeTestLive do
  use TreeOrgWeb, :live_view

  #add here for now before we fetch frm db
  #initialize data
  def mount(_params, _session, socket) do
    tree = %{
      name: "CEO",
      children: [
        %{name: "CTO",
          children: [
           %{name: "Dev", children: []},
            %{name: "QA", children: []}
          ]
        },

        %{name: "CFO",
          children: [
            %{name: "Executive",
              children: [
                %{name: "Chief Assistant", children: []}
              ]
            },

            %{name: "Accountant",
              children: [
                %{name: "CPA Officer",
                  children: [
                    %{name: "CPA Assistant", children: []}
                  ]
                }
              ]
            }
          ]
        }
      ]
    }

    roles = ["CEO", "CTO", "CFO", "Executive", "Dev", "QA", "Chief Assistant", "Accountant", "CPA Officer", "CPA assistant"]

    socket =
      socket
      |> assign(:tree, tree)
      |> assign(:form_data, %{"name" => "", "role" => "", "reports_to" => ""})
      |> assign(:dropdown_options, extract_names(tree))
      |> assign(:roles_list, roles)
      |>assign(:show_form, false) #initially hidden

    {:ok, socket}
  end

  #toggle form visibility
  def handle_event("toggle_form", _params, socket) do
    {:noreply, update(socket, :show_form, fn show -> not show end)}
  end

  #to update form when typing or selecting
  def handle_event("update_form", %{"user" => form_data}, socket) do
    {:noreply, assign(socket, :form_data, form_data)}
  end

  #for add new user logic
  def handle_event("add_user", _params, socket) do
    %{form_data: %{"name" => name, "role" => role, "reports_to" => reports_to}, tree: tree} = socket.assigns


    #to combine role and name and can be customized
    node_name = "#{role} - #{name}"

    updated_tree = insert_node(tree, reports_to, %{name: node_name, children: []})

    socket =
      socket
      |> assign(:tree, updated_tree)
      |> assign(:dropdown_options, extract_names(updated_tree))
      |> assign(:form_data, %{"name" => "", "role" => "", "reports_to" => ""})
      |> assign(:show, false) #hide form after submission

    {:noreply, socket}
  end

  #recursive helper to insert node at the correct position
  defp insert_node(%{name: target_name, children: children} =node, target_name, new_node) do
    %{node | children: children ++ [new_node]}
  end

  defp insert_node(%{children: children} = node, target_name, new_node) do
    updated_children =
      Enum.map(children, fn child ->
        insert_node(child, target_name, new_node)
      end)
    %{node | children: updated_children}
  end


  #extract all node names from dropdown
  defp extract_names(node) do
    [node.name] ++ Enum.flat_map(node.children, &extract_names/1)
  end

  # component to render tree recursively
  def render_tree(assigns) do
    ~H"""
    <div class="flex flex-col items-center relative">
      <div class="tree-node cursor-pointer px-4 py-4 border border-gray-300 bg-blue-100 text-sm rounded shadow-sm inline-block mb-3">
        <%= @node.name %>
      </div>

      <%= if @node.children != [] do %>
        <!-- vertical line from parent to children -->
        <div class="h-6 tree-line relative"></div>

        <!-- horizontal connectors and children -->
        <div class="flex justify-center space-x-4 relative">

          <!-- Horizontal line connecting children -->
          <div class="absolute top-4 w-full border-t-2 border-gray-30"></div>

          <!-- Child nodes -->
          <%= for child <- @node.children do %>
            <div class="relative z-10">
              <.render_tree node={child} />
            </div>
          <% end %>
        </div>

      <% end %>

    </div>
    """
  end
end

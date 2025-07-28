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
    children = assigns[:node].children || []
    n = Enum.count(children)
    x2s =
      if n > 0 do
        Enum.map(1..n, fn i ->
          ((100 / (n + 1)) * i)
        end)
      else
        []
      end
    assigns = Map.put(assigns, :children, children)
    assigns = Map.put(assigns, :x2s, x2s)
    ~H"""
    <div class="flex flex-col items-center relative">
      <div class="tree-node cursor-pointer px-4 py-4 border border-gray-300 bg-blue-100 text-sm rounded shadow-sm inline-block mb-3" id={"node-" <> (@node.name |> String.replace(" ", "-"))}>
        <%= @node.name %>
      </div>

      <%= if @children != [] do %>
        <div class="relative w-full flex justify-center items-start" style="height: 40px;">
          <svg width="100%" height="40" style="position: absolute; left: 0; top: 0; pointer-events: none;">
            <%= for {child, idx} <- Enum.with_index(@children) do %>
              <line
                x1="50%" y1="0"
                x2={to_string(Enum.at(@x2s, idx)) <> "%"}
                y2="40"
                stroke="#a0aec0" stroke-width="2" />
            <% end %>
          </svg>
        </div>
        <div class="flex justify-center space-x-4 relative w-full">
          <%= for child <- @children do %>
            <div class="relative z-10 flex-1 flex justify-center">
              <.render_tree node={child} />
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
end

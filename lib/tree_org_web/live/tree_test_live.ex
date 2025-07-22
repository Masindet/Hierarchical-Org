defmodule TreeOrgWeb.TreeTestLive do
  use TreeOrgWeb, :live_view

  #add here for now before we fetch frm db
  def mount(_params, _session, socket) do
    tree = %{
      name: "CEO",
      children: [
        %{name: "CTO",
        children: [
          %{name: "Dev", children: []},
          %{name: "QA", children: []}
        ]},

        %{name: "CFO",
        children: [
          %{name: "Executive", children: [
             %{name: "Chief Assistant", children: []}
          ]},
          
          %{name: "Accountant", children: [
            %{name: "CPA Officer", children: [
              %{name: "CPA Assistant", children: []}
            ]}
          ]}
        ]},


      ]
    }

    {:ok, assign(socket, tree: tree)}
  end

  # The render_tree/1 component must be a function_component
  def render_tree(assigns) do
    ~H"""
    <div class="flex flex-col items-center relative">
      <div class="tree-node cursor-pointer px-4 py-2 border border-gray-300 bg-blue-100 text-sm rounded shadow-sm inline-block mb-2">
        <%= @node.name %>
      </div>

      <%= if @node.children != [] do %>
        <!-- vertical line from parent to children -->
        <div class="h-6 border-l-2 border-gray-300"></div>

        <!-- horizontal connectors and children -->
        <div class="flex justify-center space-x-4 relative">
          <!-- Horizontal line connecting children -->
          <div class="absolute top-1/2 left-0 w-full border-t-2 border-gray-300 z-0"></div>

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

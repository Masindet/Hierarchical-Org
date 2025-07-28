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
    
    # Initialize with default tree structure
    tree = %{
      id: "ceo-1",
      name: "CEO",
      children: [
        %{id: "cto-1", name: "CTO",
          children: [
            %{id: "dev-1", name: "Dev", children: [%{id: "dev-2", name: "Hammond", children: []}]},
            %{id: "qa-1", name: "QA", children: []}
          ]
        },
        %{id: "cfo-1", name: "CFO",
          children: [
            %{id: "exec-1", name: "Executive",
              children: [
                %{id: "chief-asst-1", name: "Chief Assistant", children: []}
              ]
            },
            %{id: "accountant-1", name: "Accountant",
              children: [
                %{id: "cpa-officer-1", name: "CPA Officer",
                  children: [
                    %{id: "cpa-asst-1", name: "CPA Assistant", children: []}
                  ]
                }
              ]
            }
          ]
        }
      ]
    }
    
    :ets.insert(@table_name, {:tree, tree})
    :ets.insert(@table_name, {:version, 1})
    
    {:ok, %{}}
  end
end

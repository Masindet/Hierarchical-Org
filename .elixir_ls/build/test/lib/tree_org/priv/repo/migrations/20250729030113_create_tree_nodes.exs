defmodule TreeOrg.Repo.Migrations.CreateTreeNodes do
  use Ecto.Migration

  def change do
    create table(:tree_nodes) do
      add :name, :string, null: false
      add :parent_id, references(:tree_nodes, on_delete: :delete_all)

      timestamps()
    end

    create index(:tree_nodes, [:parent_id])
  end
end

# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     TreeOrg.Repo.insert!(%TreeOrg.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias TreeOrg.Repo
alias TreeOrg.TreeNode

# Clear existing data
Repo.delete_all(TreeNode)

# Create the organizational tree structure
ceo = Repo.insert!(%TreeNode{name: "CEO"})

cto = Repo.insert!(%TreeNode{name: "CTO", parent_id: ceo.id})
cfo = Repo.insert!(%TreeNode{name: "CFO", parent_id: ceo.id})

dev = Repo.insert!(%TreeNode{name: "Dev", parent_id: cto.id})
qa = Repo.insert!(%TreeNode{name: "QA", parent_id: cto.id})

hammond = Repo.insert!(%TreeNode{name: "Hammond", parent_id: dev.id})

exec = Repo.insert!(%TreeNode{name: "Executive", parent_id: cfo.id})
accountant = Repo.insert!(%TreeNode{name: "Accountant", parent_id: cfo.id})

chief_asst = Repo.insert!(%TreeNode{name: "Chief Assistant", parent_id: exec.id})

cpa_officer = Repo.insert!(%TreeNode{name: "CPA Officer", parent_id: accountant.id})

cpa_asst = Repo.insert!(%TreeNode{name: "CPA Assistant", parent_id: cpa_officer.id})

IO.puts("Tree structure seeded successfully!")

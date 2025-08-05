alias TreeOrg.Repo
alias TreeOrg.TreeNode

Repo.delete_all(TreeNode)

# === Helpers ===
defmodule Seeder do
  def create_team(parent, base_name, count) do
    for i <- 1..count do
      TreeOrg.Repo.insert!(%TreeOrg.TreeNode{
        name: "#{base_name} #{i}",
        parent_id: parent.id
      })
    end
  end
end

# === EXECUTIVE LEVEL ===
ceo = Repo.insert!(%TreeNode{name: "CEO"})

cto = Repo.insert!(%TreeNode{name: "CTO", parent_id: ceo.id})
cfo = Repo.insert!(%TreeNode{name: "CFO", parent_id: ceo.id})
coo = Repo.insert!(%TreeNode{name: "COO", parent_id: ceo.id})
cmo = Repo.insert!(%TreeNode{name: "CMO", parent_id: ceo.id})
cro = Repo.insert!(%TreeNode{name: "CRO", parent_id: ceo.id})
clo = Repo.insert!(%TreeNode{name: "CLO", parent_id: ceo.id})

# === ENGINEERING ===
vp_eng = Repo.insert!(%TreeNode{name: "VP of Engineering", parent_id: cto.id})

frontend_mgr = Repo.insert!(%TreeNode{name: "Frontend Manager", parent_id: vp_eng.id})
backend_mgr = Repo.insert!(%TreeNode{name: "Backend Manager", parent_id: vp_eng.id})
devops_mgr = Repo.insert!(%TreeNode{name: "DevOps Manager", parent_id: vp_eng.id})

Seeder.create_team(frontend_mgr, "Frontend Dev", 35)
Seeder.create_team(backend_mgr, "Backend Dev", 35)
Seeder.create_team(devops_mgr, "DevOps Engineer", 30)

# === QA ===
qa_mgr = Repo.insert!(%TreeNode{name: "QA Manager", parent_id: cto.id})
Seeder.create_team(qa_mgr, "QA Engineer", 25)

# === PRODUCT & DESIGN ===
vp_product = Repo.insert!(%TreeNode{name: "VP of Product", parent_id: cto.id})
pm_mgr = Repo.insert!(%TreeNode{name: "Product Manager", parent_id: vp_product.id})
ux_mgr = Repo.insert!(%TreeNode{name: "UX Manager", parent_id: vp_product.id})

Seeder.create_team(pm_mgr, "PM", 10)
Seeder.create_team(ux_mgr, "UX Designer", 10)

# === FINANCE & ACCOUNTING ===
finance_mgr = Repo.insert!(%TreeNode{name: "Finance Manager", parent_id: cfo.id})
accounting_mgr = Repo.insert!(%TreeNode{name: "Accounting Manager", parent_id: cfo.id})

Seeder.create_team(finance_mgr, "Financial Analyst", 12)
Seeder.create_team(accounting_mgr, "Accountant", 13)

# === HR ===
hr_mgr = Repo.insert!(%TreeNode{name: "HR Manager", parent_id: coo.id})
Seeder.create_team(hr_mgr, "HR Specialist", 20)

# === OPERATIONS ===
ops_mgr = Repo.insert!(%TreeNode{name: "Operations Manager", parent_id: coo.id})
Seeder.create_team(ops_mgr, "Ops Staff", 25)

# === SALES & MARKETING ===
sales_mgr = Repo.insert!(%TreeNode{name: "Sales Manager", parent_id: cro.id})
marketing_mgr = Repo.insert!(%TreeNode{name: "Marketing Manager", parent_id: cmo.id})

Seeder.create_team(sales_mgr, "Sales Rep", 15)
Seeder.create_team(marketing_mgr, "Marketing Executive", 15)

# === LEGAL ===
legal_mgr = Repo.insert!(%TreeNode{name: "Legal Manager", parent_id: clo.id})
Seeder.create_team(legal_mgr, "Legal Officer", 10)

# === SUPPORT ===
support_mgr = Repo.insert!(%TreeNode{name: "Customer Support Manager", parent_id: coo.id})
Seeder.create_team(support_mgr, "Support Agent", 20)

# === R&D ===
rnd_mgr = Repo.insert!(%TreeNode{name: "R&D Manager", parent_id: cto.id})
Seeder.create_team(rnd_mgr, "R&D Specialist", 10)

# === DONE ===
IO.puts("🎉 Seeded ~300 employees, including ~100 developers!")

declare -A roleTemplate=(
  ['Global Administrator']='62e90394-69f5-4237-9190-012177145e10'
  ['Privileged Role Administrator']='e8611ab8-c189-46e8-94e1-60213ab1f814'
  ['Application Administrator']='9b895d92-2cd3-44c7-9d02-a6ac2d5ea5c3'
  ['Groups Administrator']='fdd7a751-b60b-444a-984c-02652fe8fa1c'
  ['Directory Readers']='88d8e3e3-8f55-4a1e-953a-9b9898b8876b'
)

declare -A apiPermissions=(
  ['User.Read.All']='df021288-bdef-4463-88db-98f22de89214=Role'
  ['Application.ReadWrite.OwnedBy']='18a4783c-866b-4cc7-a460-3d5e5662c884=Role'
  ['Group.ReadWrite.All']='62a82d76-70ea-41e2-9197-370581804d09=Role'
  ['DelegatedPermissionGrant.ReadWrite.All']='8e8e4742-1d95-4f68-9d56-6ee75648c72a=Role'
)
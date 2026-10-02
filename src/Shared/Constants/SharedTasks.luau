local TasksList = require(game.ReplicatedStorage.Shared.Classes.TasksList)

return {
   WeaponThrownTasks = TasksList.new() :: TasksList.TasksList<(player: Player, toolId: string) -> ()>,
   WeaponReturnedTasks = TasksList.new() :: TasksList.TasksList<(player: Player, toolId: string) -> ()>,
   ThrownWeaponMoved = TasksList.new() :: TasksList.TasksList<(player: Player, toolId: string, newPosition: Vector3, isRecalling: boolean) -> ()>,
   ThrownWeaponRemoved = TasksList.new() :: TasksList.TasksList<(player: Player, toolId: string) -> ()>,
   PlayerUsedAbility = TasksList.new() :: TasksList.TasksList<(player: Player, abilityId: string) -> ()>,
   ThrownWeaponHitObject = TasksList.new() :: TasksList.TasksList<(player: Player, toolId: string, hitObject: Instance, hitPosition: Vector3) -> ()>,
}
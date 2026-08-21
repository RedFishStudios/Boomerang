local TasksList = require(game.ReplicatedStorage.Shared.Classes.TasksList)

return {
   ThrownWeaponMoved = TasksList.new() :: TasksList.TasksList<(player: Player, toolId: string, newPosition: Vector3, isRecalling: boolean) -> ()>,
   ThrownWeaponRemoved = TasksList.new() :: TasksList.TasksList<(player: Player, toolId: string) -> ()>,
   PlayerUsedAbility = TasksList.new() :: TasksList.TasksList<(player: Player, abilityId: string) -> ()>,
}
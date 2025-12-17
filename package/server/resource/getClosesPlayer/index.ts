import { Vector3 } from "@nativewrappers/fivem";

export function getClosestPlayer(
  coords: { x: number; y: number; z: number },
  maxDistance: number = 2.0,
  ignorePlayerId?: number | false
): [number, number, Vector3] | undefined {
  const players = GetActivePlayers();

  let closestId: number | undefined;
  let closestPed: number | undefined;
  let closestCoords: Vector3 | undefined;
  for (let i = 0; i < players.length; i++) {
    const playerId = players[i];

    if (!ignorePlayerId || playerId !== ignorePlayerId) {
      const playerPed = GetPlayerPed(playerId);
      const [x, y, z] = GetEntityCoords(playerPed, false);
      
      const dx = coords.x - x;
      const dy = coords.y - y;
      const dz = coords.z - z;
      const distance = Math.sqrt(dx * dx + dy * dy + dz * dz);

      if (distance < maxDistance) {
        maxDistance = distance;
        closestId = playerId;
        closestPed = playerPed;
        closestCoords = new Vector3(x, y, z);
      }
    }
  }

  return closestCoords ? [closestId as number, closestPed as number, closestCoords as Vector3] : undefined;
}

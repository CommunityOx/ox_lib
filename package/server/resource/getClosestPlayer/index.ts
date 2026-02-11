import { Vector3 } from "@nativewrappers/fivem";

export function getClosestPlayer(
  coords: Vector3,
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
      
      const distance = coords.distance(new Vector3(x, y, z));

      if (distance < maxDistance) {
        maxDistance = distance;
        closestId = playerId;
        closestPed = playerPed;
        closestCoords = new Vector3(x, y, z);
      }
    }
  }

  return closestCoords ? [closestId as number, closestPed as number, closestCoords] : undefined;
}

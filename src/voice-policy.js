// The last depressed key has priority in mono and legato modes.
export function previousHeld(held){const entries=[...held.entries()];return entries.length?entries.at(-1):null}
export function glideSeconds(milliseconds){return Math.max(.01,Math.min(250,Number(milliseconds)||70)/1000)}
export function glideRatio(fromMidi,toMidi){return 2**((fromMidi-toMidi)/12)}

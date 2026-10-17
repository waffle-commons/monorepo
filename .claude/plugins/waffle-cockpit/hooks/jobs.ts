/**
 * The session's background work as the cockpit tracks it: backgrounded shells,
 * monitors, subagents and the /loop wakeup. The engine gives a mod no task
 * list, so the cockpit records each start from its tool call and each end from
 * the task notification the session receives. Pure, so it is tested without an
 * engine.
 */
import type { Job, JobKind, JobState } from '../types'

/** How long an ended job stays on the line, ticked or crossed, before it goes. */
export const LINGER_MS = 60_000

/** The longest label the line shows; the pane shows the whole one. */
const LABEL_MAX = 48

/** One line of text, at most `max` characters, with an ellipsis when cut. */
export function oneLine(text: string, max = LABEL_MAX): string {
  const flat = text.replace(/\s+/g, ' ').trim()
  return flat.length > max ? `${flat.slice(0, max - 1)}…` : flat
}

/** A job that just started. */
export function jobOf(kind: JobKind, id: string, label: string, detail: string, now: number): Job {
  return { id, kind, label: oneLine(label), detail, state: 'running', startedAt: now, endedAt: null, dueAt: null, events: 0 }
}

/** Adds a job, replacing one with the same id (a re-armed monitor, a resumed agent). */
export function started(jobs: readonly Job[], job: Job): Job[] {
  return [...jobs.filter(one => one.id !== job.id), job]
}

/**
 * The task notifications a delivered prompt carries, each with its id and
 * status; one without a status is a monitor's event. A delivery may batch
 * several.
 */
export function notificationsOf(text: string): { id: string; status: string }[] {
  return text
    .split('<task-notification>')
    .slice(1)
    .flatMap(block => {
      const id = /<task-id>([^<]+)<\/task-id>/.exec(block)?.[1]?.trim()
      if (id === undefined || id === '') return []
      return [{ id, status: /<status>([^<]+)<\/status>/.exec(block)?.[1]?.trim() ?? '' }]
    })
}

/** A notification's status word as a job state: `failed`, `killed` (stopped, expired), else `completed`. */
export function stateOf(status: string): JobState {
  if (status === 'failed' || status === 'error') return 'failed'
  if (status === 'killed' || status === 'stopped' || status === 'timeout' || status === 'expired') return 'killed'
  return 'completed'
}

/** Marks a running job ended; an unknown id or an ended job is left as it was. */
export function ended(jobs: readonly Job[], id: string, state: JobState, now: number): Job[] {
  return jobs.map(job => (job.id === id && job.endedAt === null ? { ...job, state, endedAt: now } : job))
}

/** Counts one more event on a running monitor. */
export function evented(jobs: readonly Job[], id: string): Job[] {
  return jobs.map(job => (job.id === id && job.endedAt === null ? { ...job, events: job.events + 1 } : job))
}

/** What the cockpit reads of `$.agent.list()`. */
export type AgentSeen = { id: string; type: string; description: string; status: string }

const AGENT_ENDED: Record<string, JobState> = { completed: 'completed', failed: 'failed', killed: 'killed' }

/**
 * Folds `$.agent.list()` into the jobs: a new live agent starts a job, an
 * agent that ended ends its own, and a running agent the list no longer names
 * (the engine drops ended tasks) ends as completed.
 */
export function withAgents(jobs: readonly Job[], agents: readonly AgentSeen[], now: number): Job[] {
  const listed = new Map(agents.map(agent => [agent.id, agent]))
  let next = jobs.map(job => {
    if (job.kind !== 'agent' || job.endedAt !== null) return job
    const agent = listed.get(job.id)
    const state = agent === undefined ? 'completed' : AGENT_ENDED[agent.status]
    return state === undefined ? job : { ...job, state, endedAt: now }
  })
  for (const agent of agents) {
    if (AGENT_ENDED[agent.status] !== undefined || next.some(job => job.id === agent.id)) continue
    next = started(next, jobOf('agent', agent.id, agent.description || agent.type, agent.type, now))
  }
  return next
}

/** Drops the jobs ended more than `lingerMs` ago, and a wakeup whose time has come. */
export function pruned(jobs: readonly Job[], now: number, lingerMs = LINGER_MS): Job[] {
  return jobs.filter(job => {
    if (job.endedAt !== null) return now - job.endedAt < lingerMs
    return job.dueAt === null || job.dueAt > now
  })
}

/** The running jobs, oldest first. */
export function liveOf(jobs: readonly Job[]): Job[] {
  return jobs.filter(job => job.endedAt === null)
}

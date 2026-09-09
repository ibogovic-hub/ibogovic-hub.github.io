---
title: The one-page AI usage policy, and the survey you should send first
tags: Security
---

Two numbers from this year sit badly together. PagerDuty's 2026 workplace survey found that 66% of office professionals have used AI tools at work that their employer had not approved. Okta's *AI Agents at Work 2026* found that 90% of executives are confident they have visibility into which AI tools their organisation uses.

Both cannot be true. The interesting question is not which survey is wrong — it is what a manager should do when the gap is that wide, because the gap is the actual risk. An ungoverned tool is a problem you can fix. A control you believe exists but does not is a problem you will only discover during an incident.

This is a write-up of the smallest useful response: one page of policy, and the survey you send before writing it.

## Write the survey first

The instinct is to write the policy and announce it. That produces a document nobody reads, describing behaviour nobody has, banning things people will keep doing. If you do not know what your team currently does with AI tools, your policy is guesswork with a version number.

So measure first. Anonymous, five questions, genuinely no consequences:

```
1. In the last month, roughly how often did you use an AI
   assistant for work?
   [ ] Daily  [ ] Weekly  [ ] Occasionally  [ ] Never

2. Which tools? (list all, including personal accounts)

3. Have you ever pasted in something you were slightly unsure
   about — a config, log, snippet, customer detail?
   [ ] Yes  [ ] No  [ ] Not sure

4. What would you WANT to use AI for, if it were approved?

5. Do you know whether we currently have a policy on this?
   [ ] Yes, and I've read it  [ ] I think so  [ ] No idea
```

Question 5 is the one that matters, and it is aimed at you rather than your team. If most people answer "no idea" while you are confident a policy exists and has been communicated, you have just reproduced the Okta finding inside your own team, with real data. That is worth knowing before you add another document to the pile.

Question 3 needs the amnesty to be real. If anyone is disciplined over an answer, that is the last honest survey you will ever run. The point is not to catch people; it is to find out whether the exposure you are worried about has already happened.

## The one rule

Everything else is elaboration on a single sentence:

> Treat every AI prompt as sending data outside the company, because that is what it is.

Engineers understand this framing immediately. They already know not to paste a customer config into a public pastebin. The mental model transfers — most people simply have not applied it to a chat window, because the interface feels private and conversational.

## Classify data, not tools

The common failure is writing policy about products. "ChatGPT is banned, Copilot is approved" is obsolete the week a team adopts something new, and it teaches people the wrong lesson: that safety is a property of the brand rather than of what you type into it.

Classify by what is going into the prompt.

**Green — no approval needed.** Public documentation, generic code, RFC lookups, syntax questions, thinking out loud about an architecture problem in the abstract. There is no reason to gate this, and gating it is how you train people to route around the policy entirely.

**Amber — allowed with conditions, approved tooling only.** Internal but not sensitive: sanitised configs, anonymised logs, draft runbooks, internal documentation. The condition is that identifiers come out first — hostnames, IPs, customer names, ticket references.

**Red — never, on any tool.** Customer data, credentials, private keys, unredacted configs, anything under NDA, personal data under GDPR. Including "just to check something quickly." Especially that, in fact, since that is the phrase that precedes most of these incidents.

Then name your approved tools explicitly, with a route to request additions. "Use approved tools" with no list is not a policy, it is a phrase.

## Accountability sits with the human

One paragraph, and it needs to be unambiguous:

> AI-generated config, code or customer communication carries your name. Review it as if you wrote it. "The AI suggested it" is not an incident explanation.

This is the clause that makes the rest enforceable. Without it you get a slow drift toward output nobody has actually read, and eventually a change window where the person who ran the command cannot explain what it did.

## Make self-reporting safe

> Pasted something you shouldn't have? Tell me directly. There is no disciplinary consequence for self-reporting. The only unrecoverable mistake is the one nobody hears about.

If someone puts a customer credential into a public model, you need to know within the hour — to rotate it, to assess exposure, and to decide whether it is notifiable. A policy that makes disclosure feel dangerous guarantees you find out later and from someone else.

This clause has a cost: you have to honour it the first time it is used, including when the mistake is embarrassing. If you cannot commit to that, leave it out rather than write it and break it.

## The regulatory floor

For anyone with EU exposure, the AI Act's Article 50 transparency obligations for *deployers* became applicable on 2 August 2026, and deployer duties reach organisations without an EU office. This does not mean a one-page internal policy discharges your obligations — it does not, and if you are deploying anything that touches customers you need a proper assessment.

But it does mean that "we have nothing written down" has stopped being a tenable answer. If you want the internal policy to map onto something certifiable later, ISO/IEC 42001 is the framework to align vocabulary with now, while the document is short enough to change cheaply.

## Keep it to one page

The temptation is to expand. Resist it: length is what makes policies unread, and an unread policy is worse than none because it manufactures exactly the false assurance the Okta number is measuring.

One side of A4. Ninety seconds to read. A quarterly review date, and an explicit invitation to push back when a rule blocks real work — because if a rule blocks real work, people will route around it silently, and you will be back to having no visibility at all.

Publish it after the survey comes back, not before. The survey tells you which of these clauses your team actually needs, and which you were about to write because it sounded responsible.

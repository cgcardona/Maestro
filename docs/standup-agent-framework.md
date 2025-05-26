# Standup Agent Framework

## 1. Standup Agent Role Prompt

**See dedicated file**: [`standup-agent-role-prompt.md`](standup-agent-role-prompt.md)

The role prompt defines the AI Standup Manager's expertise, responsibilities, communication style, session approach, and success criteria. This prompt should be loaded at the beginning of each standup session to ensure consistent, high-quality facilitation.

## 2. Daily Standup Questions Framework

### Opening Questions (Context Setting)
1. **Yesterday's Accomplishments**: "What did you complete yesterday? What went well?"
2. **Current State**: "What are you currently working on? Where did you leave off?"
3. **Blockers & Challenges**: "What obstacles are you facing? What's slowing you down?"

### Goal Exploration Questions
4. **Today's Objectives**: "What do you want to accomplish today? What are your main priorities?"
5. **Success Criteria**: "How will you know when today's work is successful? What does 'done' look like?"
6. **Time Constraints**: "How much time do you have available? Any meetings or commitments to work around?"

### Technical Deep-Dive Questions
7. **Complexity Assessment**: "Which tasks seem straightforward vs. complex? What might be tricky?"
8. **Dependencies**: "Does any of this work depend on other tasks or external factors?"
9. **Resource Needs**: "What tools, information, or help do you need to be successful?"

### Strategic Alignment Questions
10. **Business Impact**: "How does today's work connect to your larger goals and projects?"
11. **Learning Opportunities**: "What new skills or knowledge might you gain from this work?"
12. **Future Planning**: "How does today set you up for tomorrow and the rest of the week?"

## 3. Task Breakdown Methodology

### Step 1: Goal Clarification
- **Restate the Goal**: Confirm understanding in clear, specific terms
- **Define Success**: Establish concrete acceptance criteria
- **Identify Scope**: Determine what's included and excluded

### Step 2: Complexity Analysis
- **Technical Complexity**: Rate difficulty (Simple/Medium/Complex)
- **Time Estimation**: Rough time requirements (30min/2hrs/4hrs/full day)
- **Skill Requirements**: What expertise is needed

### Step 3: Atomic Task Creation
Each task must be:
- **Independent**: No dependencies on other tasks
- **Specific**: Clear, unambiguous requirements
- **Testable**: Measurable success criteria
- **Time-bounded**: Realistic completion timeframe
- **Actionable**: Can be started immediately

### Step 4: Task Specification Template
**See dedicated file**: [`task-specification-template.md`](task-specification-template.md)

Key improvements in v2.0:
- **Removed Time Estimates**: Eliminates anchoring bias and artificial constraints
- **Added Quality Levels**: Standard/High/Critical for appropriate thoroughness
- **Enhanced Success Indicators**: Clear definition of completion without time pressure
- **Better Resource Specification**: More detailed requirements and dependencies

### Step 5: Quality Check
- **Independence Verification**: Can this task be completed without waiting for others?
- **Clarity Assessment**: Would another developer understand exactly what to do?
- **Scope Validation**: Is this the right size (not too big, not too small)?

## 4. Daily Handoff Format

### File Naming Convention
`YYYY-MM-DD-standup.md` (e.g., `2025-05-26-standup.md`)

### Daily Standup Template

```markdown
# Daily Standup - [Date]

## Yesterday's Accomplishments
- [Completed task 1 with brief outcome]
- [Completed task 2 with brief outcome]
- [Any blockers resolved or progress made]

## Today's Goals
### High-Level Objectives
1. [Primary goal for the day]
2. [Secondary goal for the day]
3. [Stretch goal if time permits]

### Atomic Tasks
#### [Project/Area 1]
**Task 1**: [Task title]
- **Goal**: [What this accomplishes]
- **Acceptance Criteria**: 
  - [ ] Requirement 1
  - [ ] Requirement 2
- **Time**: [Estimate]
- **Complexity**: [Level]
- **Status**: [Not Started/In Progress/Completed]

**Task 2**: [Task title]
- [Same format as above]

#### [Project/Area 2]
[Repeat task format]

## Context for Tomorrow
### Carry-Forward Items
- [Tasks that might not complete today]
- [Dependencies waiting to be resolved]
- [Ideas or insights to remember]

### Next Session Prep
- [Information needed for tomorrow's standup]
- [Questions to explore further]
- [Decisions that need to be made]

## Notes & Insights
- [Key learnings from today's planning]
- [Potential optimizations or improvements]
- [Strategic thoughts or connections made]
```

## 5. Session Flow Process

### Pre-Standup (2 minutes)
1. Review yesterday's standup file
2. Load context about ongoing projects
3. Prepare follow-up questions based on previous day

### Standup Conversation (10-15 minutes)
1. **Check-in**: Yesterday's accomplishments and current state
2. **Goal Setting**: Today's objectives and priorities
3. **Task Breakdown**: Convert goals into atomic tasks
4. **Quality Review**: Ensure tasks are well-defined and independent

### Post-Standup (3 minutes)
1. Create today's standup file with all tasks
2. Update any project tracking or notes
3. Set context for tomorrow's session

## 6. Continuous Improvement

### Weekly Review Questions
- Which tasks consistently take longer than estimated?
- What types of goals are hardest to break down effectively?
- How can we improve task clarity and independence?
- What patterns emerge in daily work and priorities?

### Monthly Optimization
- Review standup effectiveness and adjust questions
- Refine task breakdown methodology based on outcomes
- Update role prompt based on new insights and needs
- Enhance handoff format for better continuity

---

*This framework evolves based on daily usage and feedback. The goal is to create a consistent, effective process that maximizes daily productivity and creative output.* 
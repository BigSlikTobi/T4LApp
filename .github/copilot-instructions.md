## Bug/Error/Problem/Review Handling

When addressing bugs, errors, problems, or reviews, please follow this process:

1.  **Brainstorm Possibilities:**
    * Reflect on 5-7 different potential causes of the issue.

2.  **Distill to Likely Sources:**
    * Narrow down the possibilities to the 1-2 most likely root causes.

3.  **Validate with Logs:**
    * Add relevant logs to your code to validate your assumptions. This helps confirm the identified sources.

4.  **Implement Code Fix:**
    * Once the problem is confirmed, proceed with implementing the necessary code fix.

## Implementation Process

When implementing new features or changes, please follow this process:

1.  **Brainstorm Implementation Possibilities:**
    * Generate 5 different potential implementation approaches.

2.  **Evaluate and Select Best Approach:**
    * Evaluate each implementation based on:
        * Architecture: How well it fits with the existing system.
        * Implementation: Complexity and maintainability.
        * User Acceptance: Potential impact on user experience.
    * Select the best approach based on this evaluation.

3.  **Implement the Selected Approach:**
    * Implement the chosen approach.

4.  **Monitor Terminal for Issues:**
    * Pay close attention to the terminal output for any errors or warnings.

5.  **Address Terminal Issues:**
    * Resolve any reported issues before finalizing the implementation.

## Git Commit Message Guidelines

When creating Git commit messages, please adhere to the following guidelines:

* **Subject-Body Separation:** Separate the subject line from the body with a blank line.

* **Subject Line Punctuation:** Do not end the subject line with a period.

* **Capitalization:** Capitalize the subject line and the first word of each paragraph in the body.

* **Imperative Mood:** Use the imperative mood in the subject line (e.g., "Fix bug," not "Fixed bug").

* **Line Wrapping:** Wrap lines in the body at 72 characters.

* **Body Content:**

    * Explain *what* and *why* changes were made.

    * Avoid detailing *how* changes were implemented (focus on the outcome).

    * Describe why a change is being made.

    * Explain how it addresses the issue.

    * Detail the effects of the patch.

    * Do not assume the reviewer understands what the original problem was.

    * Do not assume the code is self-evident/self-documenting.

    * Read the commit message to see if it hints at improved code structure.

    * The first commit line is the most important.

    * Describe any limitations of the current code.

    * Do not include patch set-specific comments.
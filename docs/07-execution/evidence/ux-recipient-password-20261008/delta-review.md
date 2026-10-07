**PASS** at 59802681, going by your description of the delta. I didn't check it against the file.

Both blocking fallback issues are fixed. The fallback copy no longer claims the password was saved, offers a retry, or points to a step that isn't on the page. Each page sends users to the right person: the platform operator for admin, the company admin for member.

**Still open, not blocking:** on the member page, a password or marker hint still hides the identity, denied and malformed reasons. That predates this change and needs its own decision.
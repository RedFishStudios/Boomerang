return {
   NoAccess = 0, -- Does not own, was not gifted, no privileged access
   Owns = 1,
   Gifted = 2, -- User was gifted the gamepass but has never purchased it themselves
   Privileged = 3, -- Access granted due to special privileges (such as admin)
}
-- // An animation is either an uploaded asset (Id) or unpublished keyframe data (Clip): the name of a KeyframeSequence in
-- // Shared/AnimationClips, played by KeyframeClipTrack. Clip-only fields:
-- //   IntroClip: played once before Clip (e.g. raising into the aim before the aim loop)
-- //   LowerBodyWhileMoving: false lets go of the hips and legs while the character moves (default true)
-- //   Speed: playback rate (default 1); markers and the clip's own fade-out stretch with it
-- // Clips always apply over asset animations, so Priority doesn't apply to them.
local Animations: {
   [string]: {
      Id: number?,
      Clip: string?,
      IntroClip: string?,
      LowerBodyWhileMoving: boolean?,
      Speed: number?,
      Layer: string,
      FadeIn: number?,
      FadeOut: number?,
      Looping: boolean,
      Priority: Enum.AnimationPriority?,
   }
} = {
   Test = {
      Id = 137190745181140,
      Layer = "Test",
      Looping = true
   },

   -- // Previous uploaded-asset version, kept for reference:
   -- Charging = {
   --    Id = 130007850779400,
   --    Layer = "WeaponAction",
   --    FadeIn = .8,
   --    FadeOut = .8,
   --    Looping = true
   -- },

   Charging = {
      Clip = "BoomerangAimHold_R15", -- // Upper body only: the walk keeps the legs
      Speed = 1 / 1.08, -- // 8% slower than authored
      IntroClip = "BoomerangAimEnter_R15",
      Layer = "WeaponAction",
      FadeIn = .05, -- // The intro clip raises into the aim itself
      FadeOut = .2,
      Looping = true
   },

   -- // Previous uploaded-asset version, kept for reference:
   -- Throw = {
   --    Id = 83626657502858,
   --    Layer = "WeaponAction",
   --    FadeIn = .2,
   --    FadeOut = .8,
   --    Looping = false
   -- },

   Throw = {
      Clip = "BoomerangThrow_R15", -- // Starts at the release pose (the boomerang leaves at once); ends by easing its own weight to 0
      LowerBodyWhileMoving = false,
      Layer = "WeaponAction",
      FadeIn = .05,
      FadeOut = .2,
      Looping = false
   },

	Summon = {
		Id = 93282079872868,
		Layer = "WeaponAction",
		FadeIn = .6,
		FadeOut = .2,
		Looping = true
	},

   Catch = {
      Id = 111625966555407,
      Layer = "WeaponAction",
      FadeIn = .2,
      FadeOut = .2,
      Looping = false,
      Priority = Enum.AnimationPriority.Action,
   },

   -- // Previous uploaded-asset version, kept for reference:
   -- Stab = {
   --    Id = 137065689006321,
   --    Layer = "WeaponAction",
   --    FadeIn = .1,
   --    FadeOut = .2,
   --    Looping = false
   -- },

   Stab = {
      Clip = "BoomerangSlash_R15", -- // Ends by easing its own weight to 0
      Speed = 1 / 1.08, -- // 8% slower than authored
      LowerBodyWhileMoving = false,
      Layer = "WeaponAction",
      FadeIn = .05,
      FadeOut = .2,
      Looping = false
   },

   Dash = {
      Id = 126005747148454,
      Layer = "Ability",
      FadeIn = .05,
      FadeOut = .1,
      Looping = false
   },

   Zapped = {
      Id = 111468555566905,
      Layer = "Ability",
      FadeIn = .05,
      FadeOut = .05,
      Looping = true,
      Priority = Enum.AnimationPriority.Action4,
   }
}

return Animations
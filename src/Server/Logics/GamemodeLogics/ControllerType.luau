export type RoundController = {

   -- // Function for round beginning; establish initial state for this round
   --    Prerequisites: The arena map must already be decided and setup
   setup: ()->(),

   -- // Clean up any state or resources established for this round
   --    Fires round ended task listeners
   teardown: ()->()
}

return {}
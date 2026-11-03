# Discovery guidance

The UI adds one exploration hint per case, unread markers for discovered evidence/information, and asked/newly available question styling. Locked question labels remain concealed. Question availability is supplied by the existing session; gold means available with prerequisites, never correctness.

Reading a notebook entry, board detail, or report stores its public text hash under campaign flags.ui_reading[case_id]. Updated text becomes unread again. Browsing a list does not mark unseen details read. New-game campaign reset clears these UI preferences. They do not affect accusation scoring, evidence discovery, or provider facts.

The tutorial disappears on the first scene inspection or conversation. Notifications persist through the existing save manager. Tests: test_discovery_guidance.gd (graphical 1280×720 and reload), test_story_pacing.gd, test_campaign_flow.gd, test_noir_dialogue.gd.

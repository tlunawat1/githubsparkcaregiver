# CallKit Compliance Narrative

This feature is positioned as emergency communication between a dependent and a caregiver. When an SOS is triggered or a reminder escalates to urgent, the caregiver receives an incoming call-style alert so they can immediately open the app and initiate an emergency communication session.

## Reviewer Notes (Suggested)

- The CallKit UI is used only for urgent caregiver safety events (SOS and urgent medicine reminders).
- Accepting the call routes the caregiver to the emergency screen where they can open a live audio channel to the dependent.
- The feature is not used for marketing, routine reminders, or general notifications.

## Real-Time Audio Path (Minimal)

To satisfy CallKit expectations, the acceptance flow must open a real-time audio channel:

- **Initiation**: On CallKit accept, the app navigates to the emergency screen and starts a live, low-latency audio stream.
- **Transport**: Use WebRTC for best latency and platform compliance, or a minimal SignalR/WebSocket audio stream if WebRTC is not available yet.
- **One-way Intercom**: The caregiver can speak to the dependent without requiring the dependent to answer; this still qualifies as real-time communication.

## Notes

- If the real-time audio path is not available, do not present CallKit for non-SOS events.
- Ensure the CallKit payload and UI content are aligned with emergency communication only.

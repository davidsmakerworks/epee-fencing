# epee-fencing
AI generated epee fencing game in Godot 4.6

This is not intended to be a playable game, but is a test of various AI tools. The sport of fencing was chosen because this is something the models are likely to have less knowledge about compoared with more common sports.

The initial version was generated using OpenCode with Qwen 3.6 27B Q8_0 running in llama.cpp. Model parameters were: temp=0.6, top_p=0.95, min_p=0, top_k=20, presence_penalty=0, repeat_penalty=1.0. Enhancements were suggested and implemented by Kimi K2.6 using an API service.

Several rounds of debug prompting were required before achieving any type of usable result. Kimi K2.6 produces better code overall but still required some debugging.

<img width="1282" height="694" alt="image" src="https://github.com/user-attachments/assets/2686e2b9-8578-4833-a572-2e34dcb4bdaa" />

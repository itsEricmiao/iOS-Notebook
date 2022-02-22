ICA 2 Mobile Sensing
Fall 2021
Group Members: Joshua Sylvester, Canon Ellis, Eric Miao

For Thought Questions
If you made the FFT Magnitude Buffer a larger array, would your program still work properly? If yes, why? If not, what would you need to change?
- Yeah it still works properly, because we are just looking at more data, not changing anything functionally. It will however, probably not be as meaningful to the user if the user is looking for a real time FFT data stream. This provides more of a wholistic FFT analysis tool. 

Is pausing the audioManager object better than deallocating it when the view has disappeared (explain your reasoning)?
- Deallocation means that in the case the user comes back to the view, the memory has to be reallocated and the song has to be put back into the memory. This could take time and as long as their are no memory issues in your application there is no reason why you couldn't just leave the memory allocated in case the user comes back. In terms of user experience, pausing is also better because we'll be able to remember where the user left off and put them right back into the song seamlessly. 
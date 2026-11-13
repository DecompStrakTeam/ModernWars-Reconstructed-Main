# MW_Decoded — Quick Start

## 1. Get Godot 4.7.2 (official, stock, not the game's own exe)
Either:
winget install GodotEngine.GodotEngine
or download `Godot_v4.7.2-stable_win64.exe` from https://godotengine.org/download/archive/ —
must be exactly 4.7.2, other versions won't load the native library correctly.

## 2. Run it
Open a terminal and run (adjust the Godot path to wherever step 1 installed it):

First launch will be slow (several minutes) the .godot import cache was left out of this
backup on purpose (it's 2.4 GB and fully regenerates on its own, no point copying it). Every
launch after the first is fast.

## What's in here
- src/ the recovered GDScript (readable text, not the original developer's exact file, but a
  faithful decompile) src/ui/main.gd is the menu/UI
- native/bin/mw_conflict_core.dll the patched library. This is the real simulation core,
  with a small hand-written machine-code patch (12 instructions, fully documented in
  strakexe.md) that removes the Steam ownership check so the game runs standalone.
- native/bin/mw_conflict_core.dll.orig_backup is the untouched original library, SHA-256
- data/, assets/, the real scenarios (17 of them), maps, flags, audio, etc.

Steam is fully gone, not just unneeded. The GodotSteam addon, steam_api64.dll and
steam_appid.txt have all been deleted the patched library never calls into any of it, so
there was nothing left depending on them. Nothing to install, nothing running in the
background, no account involved at all.

## A kind word to Modern Wars from Johannas, with love

Fuck you and your god-awful attempt at a game. Having the encryption key posted in a .txt file is more than just a security flaw, it's an act of sabotage disguised as a lack of skills. The phishing email I've seen has had more attention paid to security than your game. You managed to make a text file the most vulnerable part of your whole game, which is incredibly impressive, in a really shameful way. You're not even launching a game; this is an example of a cyberattack that dresses itself up as comedy. This is absolutely tragic. And to think it can get even worse! Your Steam verification scheme is no more than a 'true or false' statement on the UI level?! Is that your idea of authentication? Not only is it not security at all, but anyone who has half a brain and a memory editor could disable it or change the value of your active variable in the DLL. The final straw? The DLL file is completely unprotected, it's not even encrypted. It's plain UTF-8 text for everyone who wishes to take a closer look at it. What ownership verification scheme did you develop, for heaven's sake? You made yourself a suggestion box that kindly asks the user not to pirate your game. I've seen more complex protection schemes implemented on a fucking microwave. Tell me how did you manage to implement Steam verification and make it even less secure than a Boolean variable in a beginner-level programming course? This is not DRM, it's just security in a decorative form. If anything, the phrase "anti-tamper" is an insult to itself used in the description of your verification scheme. Replace the whole thing with a pop-up window that says "Please don't cheat :(".

And as if the problems with the security weren't enough, here come the rest of the issues.

1. Copyright violations: There are multiple uses of copyrighted material in the game. Checking whether you are allowed to use someone's else work seems to have not been a priority in the development of the game.

2. Live data editing: The game data that supposedly updates in real time can be changed by simply opening a text file in Notepad. This is definitely not the way to do live data management.

3. Steam verification: The game's anti-spoofing seems to consist in checking for Steam processes to be running. This is all the verification there is. There's nothing about verifying ownership or anything like that. Applications able to emulate Steam can bypass such a ridiculous solution. Instead of creating a DRM system, you created a process detector with an identity crisis.

4. Debugging: There are apparently no debug flags anywhere in the whole game. Congratulations, you made debugging your software not only unnecessary but also much harder at the same time.

5. False RNG claims: You are advertising RNG mechanics on your Steam page, but your code has deterministic behavior. This is not procedural randomness. That is a deterministically generated sequence which was advertised as something else. At this point, even your marketing apparently runs on a different version of your game than your game.

6. Internet connection required: Why the fuck do you need Wi-Fi for this game? Why does this game require the internet when it doesn't have any online functions besides the fact that it is run via Steam? If there is no essential online functionality, then you have successfully restricted access to your game without providing anything in return.

7. Reverse engineering: It took approximately TEN MINUTES to understand the inner workings of your game. Ten. Minutes. It takes more time to make a cup of coffee. Your so-called secured software was completely vulnerable.

8. The DLL: Finally, a model from 2024 successfully managed to fully decompile the DLL. Not some fancy new specialized security research tool. A model from 2024. It seems that not even artificial intelligence had problems comprehending an architecture that its developers clearly put next to zero effort to protect.

And the best part? YOU SPENT OVER $500 TO DEVELOP THIS.

Over five hundred dollars, with Claude, Gemini, and other AI models used in development, with the result being an application that features exposed encryption keys, a pathetic Steam verification system, easily editable live data, almost no debugging system whatsoever, and a DLL that can be decompiled in minutes.

You had some of the best development assistance available to you, and you somehow managed to produce something that appears to be a collection of scripts and poorly implemented ideas based on an AI's first suggestion.

THE BEST OF ALL!!!

Now I don't know which is more alarming, the insecurity of the game, the dubious copyright claim, the misinformation on the store page, or the fact that well over $500 went into this.

This isn’t a situation of a couple of oversights. It’s a matter of multiple development, security and quality control oversights which should have been noticed before the game even made it to Steam.

You didn’t create a secure game. What you created was a pile of text files, Boolean checks and dubious design, and slapped it into a Steam listing.

Someone just looked inside. Took him ten minutes.

The biggest threat to your game wasn't some hacker, cracker, or an expert reverse engineering crew. It was a guy with Notepad, some knowledge of DLLs and ten free minutes.

Fucking magnificent work. Not the game. The incompetence.

And the most embarrassing thing is that it took **TEN FUCKING MINUTES**.

Ten minutes to figure out everything about encryption keys, to understand the encoding scheme used in DLLs and to decrypt them.

Think about this: someone who had only recently joined the team and who was unfamiliar with project internals did all of that within a time span it takes to brew a cup of coffee.

Where is the security? Where is the obfuscation? Where is the supposedly advanced encryption? Because, however you did it, it seems that it is not enough to withstand ten minutes of analysis.

You invested several hundred dollars in developing the game with AI assistance and someone who joined your team recently has understood and decrypted it in ten minutes.

This is not an amazing reverse engineering trick. This is a complete lack of even basic security.

But the really frightening thing here is that apparently the effort required for it was so low that someone who joined the team recently managed to do all that in ten minutes.

Your system wasn't designed to be hard to crack. It was hard to realize it was this easy.

Ten minutes. This is all it took for the problem to become apparent, when it could have been caught during development.

In all honesty, I don’t know if it’s impressive to see how quickly it was solved, or worrying how easily it was.

Now, love and cheers from Johannas, Amsterdam <3

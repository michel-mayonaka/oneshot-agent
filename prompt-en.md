mkdir animal-tower && cd animal-tower

codex exec --skip-git-repo-check --full-auto --model gpt-5.2-codex "
Create a browser-only game similar to 'Animal Tower Battle' with image assets only (no animations).
Tech constraints:
- Use HTML + Canvas + JavaScript.
- Use Matter.js from a CDN for physics (no build tools).
- Provide files: index.html, style.css, game.js, animals.json, README.md.
- Assets path: ./assets/animals/*.png (do NOT generate real images; use colored placeholders if missing).
Gameplay:
- Spawn one animal at the top center. Player can move it left/right with mouse movement.
- Click or Space to drop it. After it settles (sleeping), spawn next animal.
- Use simple collision shapes first (circle or rectangle) per animal definition in animals.json.
- Add ground and side walls. If any animal falls below a 'fail line', game over with restart.
- Score: number of animals successfully stacked. Show next animal preview.
Robustness:
- Handle missing images gracefully (draw a colored rounded rect with the animal name).
- Clamp max angular velocity and set reasonable friction/restitution to avoid bouncing chaos.
- Add a 'Reset' button and 'R' key.
README:
- How to run locally with 'python -m http.server' and open in browser.
"


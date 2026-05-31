# Deployment Guide for Student Talent Profiling App (Web)

This guide explains how to deploy your Flutter web app for free so you can demo it to others.

## Option 1: GitHub Pages (Recommended for ease of use)

Since you likely already have this project on GitHub, this is the easiest way.

1.  **Build the project for web:**
    ```bash
    flutter build web --release --base-href "/<REPO_NAME>/"
    ```
    *Replace `<REPO_NAME>` with your GitHub repository name (e.g., if your repo is `my-app`, use `--base-href "/my-app/"`).*
    *If you are deploying to a custom domain or the root of a user site (`username.github.io`), use `--base-href "/"`.

2.  **Deploy using `gh-pages` package (One-time setup):**
    *   Install the deployer (if you have Node.js):
        ```bash
        npm install -g gh-pages
        ```
    *   Or, manually:
        1.  Go to `build/web`.
        2.  Initialize a git repo inside `build/web`: `git init`
        3.  Add remote: `git remote add origin https://github.com/<USERNAME>/<REPO_NAME>.git`
        4.  Checkout `gh-pages` branch: `git checkout -b gh-pages`
        5.  Add all files: `git add .`
        6.  Commit: `git commit -m "Deploy to GitHub Pages"`
        7.  Push: `git push -f origin gh-pages`

3.  **Enable GitHub Pages:**
    *   Go to your repository Settings > Pages.
    *   Select the `gh-pages` branch as the source.
    *   Your app will be live at `https://<USERNAME>.github.io/<REPO_NAME>/`.

## Option 2: Firebase Hosting (Best performance)

1.  **Install Firebase CLI:**
    ```bash
    npm install -g firebase-tools
    ```

2.  **Login:**
    ```bash
    firebase login
    ```

3.  **Initialize:**
    ```bash
    firebase init hosting
    ```
    *   Select your project (or create a new one).
    *   **Public directory:** `build/web`
    *   **Configure as a single-page app?** `Yes`
    *   **Set up automatic builds and deploys with GitHub?** `No` (unless you want to).

4.  **Build and Deploy:**
    ```bash
    flutter build web --release
    firebase deploy
    ```

## Testing Locally
To test the build locally before deploying:
```bash
cd build/web
python -m http.server 8000
```

## Option 3: Vercel (Terminal / CLI)

If you prefer using the terminal, Vercel is a great option for static hosting.

1.  **Install Vercel CLI:**
    ```bash
    npm install -g vercel
    ```

2.  **Login:**
    ```bash
    vercel login
    ```

3.  **Build and Deploy:**
    Since Vercel doesn't have Flutter installed by default, it's easiest to build locally and deploy the output.

    ```bash
    # 1. Build the web app
    flutter build web --release

    # 2. Go into the build folder
    cd build/web

    # 3. Deploy to Vercel
    vercel --prod
    ```
    *   Follow the prompts (Set up and deploy? [Y], Scope? [Select your account], Link to existing project? [N], Project Name? [Enter name], In which directory? [.]).
    *   It will give you a production URL (e.g., `https://talent-app.vercel.app`).

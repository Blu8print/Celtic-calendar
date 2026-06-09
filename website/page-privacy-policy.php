<?php
/**
 * Template Name: Privacy Policy
 * Description: Full-width privacy policy page for Roots Calendar
 */

get_header(); ?>

<main class="rc-privacy">
    <div class="rc-privacy__container">

        <header class="rc-privacy__header">
            <h1 class="rc-privacy__title">Privacy Policy</h1>
            <p class="rc-privacy__meta">Roots Calendar &mdash; Last updated: April 16, 2026</p>
            <div class="rc-privacy__summary">
                <span class="rc-privacy__summary-icon">🔒</span>
                <p>Roots Calendar stores all your data locally on your device. We do not collect, transmit, or store any personal information on our servers &mdash; because we have no servers.</p>
            </div>
        </header>

        <section class="rc-privacy__section">
            <h2>1. Who We Are</h2>
            <p>Roots Calendar is developed and maintained by Sebastiaan Castenmiller / Blu8print (<code>nl.blu8print.rootscalendar</code>). If you have questions about this policy, you can reach us at <a href="mailto:privacy@blu8print.com">privacy@blu8print.com</a>.</p>
        </section>

        <section class="rc-privacy__section">
            <h2>2. Data We Collect</h2>
            <p>We collect no personal data. The app does not transmit any information to our servers &mdash; Blu8print has no backend infrastructure for this app.</p>
            <p>All data you enter (calendar events, titles, descriptions, colors) is stored exclusively on your device using a local SQLite database (via the Drift library). This data never leaves your device unless you explicitly enable Google Calendar sync (see section 3).</p>
            <p>The app collects no:</p>
            <ul>
                <li>Analytics or usage statistics</li>
                <li>Crash reports sent to us</li>
                <li>Advertising identifiers</li>
                <li>Location data</li>
                <li>Device identifiers</li>
                <li>Contact lists or other system data</li>
            </ul>
        </section>

        <section class="rc-privacy__section">
            <h2>3. Google Calendar Sync (Optional)</h2>
            <p>Roots Calendar includes an optional feature to sync your events with Google Calendar. This feature is disabled by default and only activated when you explicitly sign in with your Google account.</p>
            <p>When you enable sync:</p>
            <ul>
                <li>The app communicates directly and exclusively between your device and Google&rsquo;s servers using the official Google Calendar API. No data passes through any intermediate server owned or operated by Blu8print.</li>
                <li>The app requests the <code>https://www.googleapis.com/auth/calendar</code> OAuth scope to read and write events in your Google Calendar.</li>
                <li>Your Google credentials (OAuth tokens) are stored only on your device by the Google Sign-In SDK and are never transmitted to us.</li>
                <li>Your use of Google Calendar is governed by <a href="https://policies.google.com/privacy" target="_blank" rel="noopener noreferrer">Google&rsquo;s Privacy Policy</a>.</li>
            </ul>
        </section>

        <section class="rc-privacy__section">
            <h2>4. Third-Party Services</h2>
            <p>Roots Calendar does not integrate with any analytics platforms, advertising networks, or other third-party data processors. The only external service the app may contact is the Google Calendar API, and only when you have opted in to sync.</p>
        </section>

        <section class="rc-privacy__section">
            <h2>5. Data Retention and Deletion</h2>
            <p>Because all data resides on your device, you are in full control:</p>
            <ul>
                <li>Delete individual events from within the app at any time.</li>
                <li>Remove all app data by uninstalling the app or clearing its storage through your device&rsquo;s <strong>Settings &rarr; Apps</strong> menu. This permanently deletes the local SQLite database.</li>
                <li>Revoke Google Calendar access at any time by visiting <a href="https://myaccount.google.com/permissions" target="_blank" rel="noopener noreferrer">myaccount.google.com/permissions</a>, finding &ldquo;Roots Calendar&rdquo;, and removing access. Revoking access does not delete events already written to Google Calendar; you may delete those from within Google Calendar directly.</li>
            </ul>
        </section>

        <section class="rc-privacy__section">
            <h2>6. Children&rsquo;s Privacy</h2>
            <p>Roots Calendar is not directed at children under 13. We do not knowingly collect data from children.</p>
        </section>

        <section class="rc-privacy__section">
            <h2>7. Changes to This Policy</h2>
            <p>If we make material changes to this privacy policy, we will update the &ldquo;Last updated&rdquo; date at the top of this page and, where appropriate, notify users through the app or the app store listing.</p>
        </section>

        <section class="rc-privacy__section">
            <h2>8. Contact</h2>
            <p>For any privacy-related questions or requests, please contact: <a href="mailto:privacy@blu8print.com">privacy@blu8print.com</a></p>
        </section>

        <footer class="rc-privacy__footer">
            <p>&copy; 2026 Sebastiaan Castenmiller / Blu8print. All rights reserved.</p>
        </footer>

    </div>
</main>

<style>
.rc-privacy {
    padding: 60px 20px 80px;
    font-family: inherit;
    color: inherit;
}

.rc-privacy__container {
    max-width: 760px;
    margin: 0 auto;
}

.rc-privacy__header {
    margin-bottom: 48px;
    padding-bottom: 32px;
    border-bottom: 1px solid currentColor;
    opacity: 0.9;
}

.rc-privacy__title {
    font-size: clamp(2rem, 5vw, 3rem);
    margin: 0 0 8px;
    font-weight: 700;
    letter-spacing: -0.02em;
}

.rc-privacy__meta {
    font-size: 0.9rem;
    opacity: 0.6;
    margin: 0 0 24px;
}

.rc-privacy__summary {
    display: flex;
    gap: 16px;
    align-items: flex-start;
    padding: 20px 24px;
    background: rgba(128, 128, 128, 0.08);
    border-left: 3px solid currentColor;
    border-radius: 4px;
}

.rc-privacy__summary-icon {
    font-size: 1.4rem;
    flex-shrink: 0;
    line-height: 1.5;
}

.rc-privacy__summary p {
    margin: 0;
    font-size: 0.95rem;
    line-height: 1.6;
}

.rc-privacy__section {
    margin-bottom: 40px;
}

.rc-privacy__section h2 {
    font-size: 1.2rem;
    font-weight: 600;
    margin: 0 0 12px;
    letter-spacing: -0.01em;
}

.rc-privacy__section p {
    font-size: 0.95rem;
    line-height: 1.75;
    margin: 0 0 12px;
}

.rc-privacy__section ul {
    padding-left: 20px;
    margin: 8px 0 12px;
}

.rc-privacy__section ul li {
    font-size: 0.95rem;
    line-height: 1.75;
    margin-bottom: 6px;
}

.rc-privacy__section a {
    text-decoration: underline;
    text-underline-offset: 3px;
}

.rc-privacy__section code {
    font-family: monospace;
    font-size: 0.85em;
    padding: 2px 6px;
    background: rgba(128, 128, 128, 0.12);
    border-radius: 3px;
}

.rc-privacy__footer {
    margin-top: 60px;
    padding-top: 24px;
    border-top: 1px solid currentColor;
    opacity: 0.5;
    font-size: 0.85rem;
}
</style>

<?php get_footer(); ?>

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
            <p class="rc-privacy__meta">Roots Calendar &mdash; Last updated: June 14, 2026</p>
            <div class="rc-privacy__summary">
                <span class="rc-privacy__summary-icon">🔒</span>
                <p>Roots Calendar stores all your data locally on your device. We do not collect, transmit, or store any personal information on our servers &mdash; because we have no servers. Google Calendar sync is strictly optional, works device-to-Google directly, and is never used to train AI or share data with third parties.</p>
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
            <h2>3. Google Calendar Sync (Optional) and Google User Data</h2>
            <p>Roots Calendar includes an <em>optional</em> feature to sync your events with Google Calendar. This feature is disabled by default and only activated when you explicitly sign in with your Google account in the app&rsquo;s Settings screen.</p>
            <p>Our use of information received from Google APIs adheres to the <a href="https://developers.google.com/terms/api-services-user-data-policy" target="_blank" rel="noopener noreferrer">Google API Services User Data Policy</a>, including the Limited Use requirements.</p>

            <div class="rc-privacy__google-box">

                <h3>A. Data Accessed</h3>
                <p>When you enable Google Calendar sync, Roots Calendar requests the OAuth 2.0 scope <code>https://www.googleapis.com/auth/calendar.events</code> and accesses:</p>
                <ul>
                    <li>Your Google Calendar event data (event title, description, start/end date) &mdash; only for calendars you choose to sync to</li>
                    <li>Your Google account identity (name and email address) &mdash; solely to display which account is connected in the Settings screen</li>
                </ul>
                <p>No other Google user data is accessed.</p>

                <h3>B. Data Usage</h3>
                <p>Google user data accessed by Roots Calendar is used solely to:</p>
                <ul>
                    <li><strong>Write</strong> events you create in Roots Calendar to your Google Calendar, so they appear in other Google Calendar clients</li>
                    <li><strong>Read</strong> events from your Google Calendar and display them alongside your local Roots Calendar entries</li>
                    <li><strong>Display</strong> your connected Google account name/email in the Settings screen</li>
                </ul>
                <p>Google user data is <strong>never</strong> used to develop, improve, or train any generalized AI or machine learning models. It is not used for advertising, profiling, or any purpose beyond the calendar synchronisation feature described above.</p>

                <h3>C. Data Sharing</h3>
                <p>Google user data accessed through Roots Calendar is <strong>not shared with any third party</strong>, including Blu8print&rsquo;s own servers (which do not exist for this app). All communication occurs directly between your device and Google&rsquo;s servers via the official Google Calendar API. No intermediate server, proxy, or analytics service touches your Google data.</p>

                <h3>D. Data Storage &amp; Protection</h3>
                <ul>
                    <li><strong>OAuth tokens</strong> (the credentials that allow the app to access your Google Calendar) are stored exclusively on your device by the Google Sign-In SDK, in the platform&rsquo;s secure credential storage (Android Keystore / iOS Keychain). They are never written to our servers or included in backups we control.</li>
                    <li><strong>Event data synced from Google Calendar</strong> is cached locally in the app&rsquo;s SQLite database for display purposes. This local cache is protected by your device&rsquo;s standard storage encryption.</li>
                    <li>All API communication uses HTTPS/TLS as enforced by the Google API client libraries.</li>
                </ul>

                <h3>E. Data Retention &amp; Deletion</h3>
                <ul>
                    <li><strong>Revoke Google Calendar access</strong> at any time by visiting <a href="https://myaccount.google.com/permissions" target="_blank" rel="noopener noreferrer">myaccount.google.com/permissions</a>, finding &ldquo;Roots Calendar&rdquo;, and removing access. You can also sign out from within the app&rsquo;s Settings screen, which clears your local OAuth tokens immediately.</li>
                    <li>Revoking access stops all future sync. Events already written to Google Calendar remain there and can be deleted from within Google Calendar directly.</li>
                    <li>The local cache of Google Calendar events is deleted automatically when you sign out of Google in the app, or when you uninstall the app / clear its storage via your device&rsquo;s Settings &rarr; Apps menu.</li>
                    <li>To request deletion of any account-related data, contact us at <a href="mailto:privacy@blu8print.com">privacy@blu8print.com</a>. We will respond within 30 days.</li>
                </ul>

            </div>
        </section>

        <section class="rc-privacy__section">
            <h2>4. Third-Party Services</h2>
            <p>Roots Calendar does not integrate with any analytics platforms, advertising networks, or other third-party data processors. The only external service the app may contact is the Google Calendar API, and only when you have opted in to sync. Your use of Google&rsquo;s services is also governed by <a href="https://policies.google.com/privacy" target="_blank" rel="noopener noreferrer">Google&rsquo;s Privacy Policy</a>.</p>
        </section>

        <section class="rc-privacy__section">
            <h2>5. Local Event Data</h2>
            <p>Events, titles, descriptions, and colors you enter manually in Roots Calendar are stored only in the local SQLite database on your device. You are in full control:</p>
            <ul>
                <li>Delete individual events from within the app at any time.</li>
                <li>Remove all app data by uninstalling the app or clearing its storage through your device&rsquo;s <strong>Settings &rarr; Apps</strong> menu. This permanently deletes the local database.</li>
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
            <p>For any privacy-related questions, requests, or to ask us to delete your data, please contact: <a href="mailto:privacy@blu8print.com">privacy@blu8print.com</a></p>
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

.rc-privacy__google-box {
    margin-top: 20px;
    padding: 8px 24px 4px;
    background: rgba(128, 128, 128, 0.05);
    border: 1px solid rgba(128, 128, 128, 0.18);
    border-radius: 6px;
}

.rc-privacy__google-box h3 {
    font-size: 1rem;
    font-weight: 600;
    margin: 20px 0 8px;
    letter-spacing: -0.01em;
}

.rc-privacy__google-box h3:first-child {
    margin-top: 16px;
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

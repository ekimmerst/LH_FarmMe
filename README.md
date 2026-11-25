<h1 style="color: #d9a94b;">LH FarmMe</h1>

<p>Keep several item-farming goals in view while you play. LH FarmMe shows a slim gold handle at the top of the screen and compact progress bars for the items you want to collect.</p>

<h2 style="color: #73c9c4;">What it does</h2>

<ul>
  <li>Hover over the gold handle to open the goal editor. Enter an item name, item ID or item link, set a target quantity and click <strong>Farm Me!</strong>.</li>
  <li>Use <strong>Alt + Shift + left click</strong> on an item in your bags to fill in its name and current bag quantity automatically. The quantity field is focused and selected so you can immediately replace it with a target. The shortcut can be changed or disabled.</li>
  <li>Track several items at once. Goals are sorted by item name and saved per character.</li>
  <li>Show each item's icon, name and collected quantity on a progress bar. Hover over the icon for the normal item tooltip.</li>
  <li>Keep every progress bar at the width needed by the longest name and quantity, up to the available space. The bars are centered below the handle with a small gap between goals.</li>
  <li>Flash the newly gained section of a bar when the item count rises. Completing a goal shows an animated achievement-style alert with the item's icon.</li>
  <li>Click the small gold-bordered <strong>x</strong> beside a bar to remove that goal.</li>
</ul>

<h2 style="color: #c78be6;">Progress and item names</h2>

<p>A new goal starts with the quantity already in your bags. LH FarmMe adds later increases in your bag count to that goal's progress. Using, selling or moving an item out of your bags does not erase progress. Existing goals are brought up to at least the current bag quantity when you log in. Bank items are not counted.</p>

<p>Item IDs and links work even before the game's item name is cached. The displayed name and position in the sorted list update when WoW provides the item data. If a typed name cannot be found in the item cache, enter its ID or link instead. Entering an item that already has a goal changes its target quantity without resetting its collected progress.</p>

<h2 style="color: #c78be6;">Handle and shortcut</h2>

<p>The gold handle starts centered in the upper-right half of the screen, docked to the top edge. Drag it along the top to move the goals. The goal editor closes after you move away from the handle and editor; it stays open while an input field has focus. Its position is saved per character.</p>

<p>Open <strong>Options &rarr; AddOns &rarr; LH Tweaks &rarr; LH FarmMe</strong> to choose the inventory shortcut. You can select Alt, Ctrl or Shift with left click, combinations of those keys, or <strong>Disabled</strong>. The default is <strong>Alt + Shift + left click</strong>. If the chosen combination opens Blizzard's stack-splitting dialog, LH FarmMe closes that dialog for the farm shortcut and focuses its own quantity field.</p>

<p>The same settings page has <strong>Reset position</strong>, which returns the handle to its default top dock, and <strong>Clear goals</strong>, which removes every saved goal for this character.</p>

<h2 style="color: #73c9c4;">More LH addons</h2>

<p>Choose only the pieces you want. LH FarmMe and most companion addons require LH Tweaks.</p>

<ul>
  <li><strong>LH Fishing:</strong> Compact fishing controls, catch history and session goals.</li>
  <li><strong>LH Range:</strong> Melee range, spell-range zones and resource feedback.</li>
  <li><strong>LH Socials:</strong> A compact guild and friends roster.</li>
  <li><strong>LH Stats:</strong> Money, free bag slots and remaining ammo below the minimap.</li>
  <li><strong>LH Tweaks:</strong> The shared settings hub and UI tweaks.</li>
</ul>

<h2 style="color: #d9a94b;">Installation</h2>

<p><strong>LH Tweaks is required.</strong> Place the <code>LH_FarmMe</code> folder beside <code>LH_Tweaks</code> in <code>World of Warcraft/_forever_/Interface/AddOns</code> and restart the game. LH Fishing, LH Range and LH Socials are not required; the progress-bar texture is included with LH FarmMe.</p>

<h2 style="color: #73c9c4;">Changelog</h2>

<p><strong>1.0.1 - Forever and Retail</strong></p>

<ul>
  <li>Prefill the target quantity with the current total across bag stacks when using the inventory shortcut. Focus and select that quantity after Blizzard's stack-splitting dialog closes.</li>
  <li>Read bag slots directly when the client's item-count API does not provide the current quantity.</li>
</ul>

<p><strong>1.0.0 - Initial release</strong></p>

<ul>
  <li>Added multiple per-character farming goals with bag-based progress, sorting, icons, tooltips, feedback animations and completion alerts.</li>
  <li>Added the top-docked hover editor, configurable inventory shortcut and LH Tweaks settings page.</li>
</ul>

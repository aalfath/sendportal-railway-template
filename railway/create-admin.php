<?php
// Creates the first SendPortal admin and workspace from variables, so the
// public /setup page is never left open for the first visitor to claim.
declare(strict_types=1);

require '/var/www/html/vendor/autoload.php';
$app = require '/var/www/html/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

use App\Models\User;
use App\Models\Workspace;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

if (User::query()->exists()) {
    echo "SendPortal admin already exists: skipping first-user setup.\n";
    exit(0);
}

$email = trim((string) getenv('SENDPORTAL_ADMIN_EMAIL'));
$password = (string) getenv('SENDPORTAL_ADMIN_PASSWORD');
$name = trim((string) (getenv('SENDPORTAL_ADMIN_NAME') ?: 'Admin'));
$company = trim((string) (getenv('SENDPORTAL_WORKSPACE_NAME') ?: 'SendPortal'));

if ($email === '' || ! filter_var($email, FILTER_VALIDATE_EMAIL)) {
    fwrite(STDERR, "SENDPORTAL_ADMIN_EMAIL must be a valid email address.\n");
    exit(1);
}
if (strlen($password) < 8) {
    fwrite(STDERR, "SENDPORTAL_ADMIN_PASSWORD must be at least 8 characters.\n");
    exit(1);
}

DB::transaction(function () use ($email, $password, $name, $company) {
    $user = User::create([
        'name' => $name,
        'email' => $email,
        'email_verified_at' => now(),
        'password' => Hash::make($password),
    ]);
    $workspace = Workspace::create(['name' => $company, 'owner_id' => $user->id]);
    $user->workspaces()->attach($workspace->id, ['role' => Workspace::ROLE_OWNER]);
});

echo "Created the SendPortal admin {$email} and workspace \"{$company}\".\n";

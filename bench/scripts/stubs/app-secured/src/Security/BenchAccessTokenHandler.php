<?php

declare(strict_types=1);

namespace App\Security;

use Symfony\Component\Security\Core\Exception\BadCredentialsException;
use Symfony\Component\Security\Http\AccessToken\AccessTokenHandlerInterface;
use Symfony\Component\Security\Http\Authenticator\Passport\Badge\UserBadge;

/**
 * Engine D's bearer-token handler. No bench request carries a token, so this
 * only runs for the feature check: every presented token is refused (401), as
 * Engine A refuses a bearer token that fails its JWT verification. What the
 * bench measures is the authenticator's header check, which runs on every
 * request whether or not a token follows.
 */
final class BenchAccessTokenHandler implements AccessTokenHandlerInterface
{
    #[\Override]
    public function getUserBadgeFrom(#[\SensitiveParameter] string $accessToken): UserBadge
    {
        throw new BadCredentialsException('Invalid credentials.');
    }
}

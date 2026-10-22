<?php

declare(strict_types=1);

namespace App\EventSubscriber;

use Symfony\Component\EventDispatcher\EventSubscriberInterface;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\Event\RequestEvent;
use Symfony\Component\HttpKernel\KernelEvents;

/**
 * Engine D's counterpart of Waffle's CorsMiddleware with Engine A's empty
 * allow-list (waffle.security.cors.allowed_origins: []): a request without an
 * Origin, or from its own origin, passes; every cross-origin request, preflight
 * or not, gets 403. k6 sends no Origin, so on the bench this is one header read
 * per request on both engines.
 */
final class CorsSubscriber implements EventSubscriberInterface
{
    #[\Override]
    public static function getSubscribedEvents(): array
    {
        // Before RouterListener (32), as Waffle answers CORS before routing.
        return [KernelEvents::REQUEST => ['onKernelRequest', 64]];
    }

    public function onKernelRequest(RequestEvent $event): void
    {
        if (!$event->isMainRequest()) {
            return;
        }

        $request = $event->getRequest();
        $origin = $request->headers->get('Origin', '');
        if ($origin === '' || $origin === $request->getSchemeAndHttpHost()) {
            return;
        }

        $event->setResponse(new Response('', Response::HTTP_FORBIDDEN));
    }
}

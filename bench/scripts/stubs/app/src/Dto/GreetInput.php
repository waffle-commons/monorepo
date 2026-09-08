<?php

declare(strict_types=1);

namespace App\Dto;

use Symfony\Component\Validator\Constraints as Assert;

/**
 * Input DTO for POST /greet — mirrors the Waffle skeleton's HelloInput
 * validation cost (non-empty, bounded length) with the idiomatic Symfony
 * validator. Hydrated by #[MapRequestPayload] (serializer denormalization
 * then validation; invalid input -> 422, same contract as engine A).
 */
final class GreetInput
{
    public function __construct(
        #[Assert\NotBlank]
        #[Assert\Length(min: 1, max: 100)]
        public readonly string $name,
    ) {
    }
}

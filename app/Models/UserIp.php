<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class UserIp extends Model
{
    protected $fillable = [
        'ip_address',
        'type',
    ];

    /**
     * Get the user that owns the UserIp
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}

<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class UserIp extends Model
{
    protected $fillable = [
        'ip_address',
        'type',
    ];
}

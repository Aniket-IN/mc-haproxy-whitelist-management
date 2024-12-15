<?php

use App\Http\Controllers\Api\V1\WhitelistIpController;
use Illuminate\Support\Facades\Route;

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/whitelist-ip', [WhitelistIpController::class, 'store']);
});

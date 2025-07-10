<?php

namespace App\Http\Controllers;

use App\Models\UserIp;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;

class WhitelistIpController extends Controller
{
    public function store(Request $request)
    {
        $ip_address = $request->ip();

        $request->user()->ips()->delete();

        $ip = $request->user()->ips()->create([
            'ip_address' => $ip_address,
            'type' => 'whitelist',
        ]);

        DB::transaction(function () {
            $ips = UserIp::with(['user'])->lockForUpdate()->get();

            $addresses = [];
            $details = [];

            foreach ($ips as $ip) {
                $addresses[] = $ip->ip_address;
                $details[] = $ip->user->name;
            }

            $client = Http::baseUrl(config('services.pfsense.api_host'))
                ->withBasicAuth(
                    config('services.pfsense.credentials.username'),
                    config('services.pfsense.credentials.password')
                );

            $response = $client->get('/api/v2/firewall/aliases', [
                'type' => 'host',
                'name' => 'Minecraft_Whitelisted_IPs',
            ]);

            if (! $aliasId = $response->json('data.0.id')) {
                throw new \Exception('Alias not found');
            }
            
            $response = $client->patch('/api/v2/firewall/alias', [
                'id' => $aliasId,
                'address' => $addresses,
                'detail' => $details,
                'apply' => true,
            ]);

            if ($response->json('code') !== 200) {
                throw new \Exception('Failed to update alias');
            }
        });

        return $ip;
    }
}

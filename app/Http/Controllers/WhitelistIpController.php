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
            $ips = UserIp::lockForUpdate()->get();

            $client = Http::baseUrl(config('services.haproxy.api_host'))
                ->withBasicAuth(config('services.haproxy.credentials.username'), config('services.haproxy.credentials.password'));

            $endpoint = '/v3/services/haproxy/configuration/frontends/minecraft-in/acls';

            $response = $client->throw()->get($endpoint);

            $version = $response->header('Configuration-Version');

            $data = [];

            foreach ($ips as $ip) {
                $data[] = [
                    'acl_name' => 'whitelist',
                    'criterion' => 'src',
                    'value' => $ip->ip_address,
                ];
            }

            $client->throw()->withQueryParameters([
                'version' => $version,
            ])->put($endpoint, $data);
        });

        return $ip;
    }
}

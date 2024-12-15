import useAxios from "@/Hooks/useAxios";
import AuthenticatedLayout from "@/Layouts/AuthenticatedLayout";
import { Head, usePage } from "@inertiajs/react";
import { useQuery } from "@tanstack/react-query";
import { AxiosError, AxiosResponse } from "axios";

export default function Dashboard() {
    const user = usePage().props.auth.user;

    const { isLoading, isSuccess, isError, data } = useQuery<
        AxiosResponse<{
            ip_address: string;
        }>,
        AxiosError
    >({
        queryKey: ["whitelist-ip"],
        queryFn: () => axios.post("/whitelist-ip"),
    });

    return (
        <AuthenticatedLayout
            header={
                <h2 className="text-xl font-semibold leading-tight text-gray-800">
                    Dashboard
                </h2>
            }
        >
            <Head title="Dashboard" />

            <div className="py-12">
                <div className="mx-auto max-w-7xl sm:px-6 lg:px-8">
                    <div className="overflow-hidden bg-white shadow-sm sm:rounded-lg">
                        <div className="p-6 text-gray-900">
                            <div>
                                {isLoading && "Loading...."}
                                {isSuccess && data.data && (
                                    <div className="space-y-5">
                                        <p>
                                            ✅ You'r IP (
                                            <b>{data.data.ip_address}</b>) is
                                            now whitelisted
                                        </p>

                                        <p>Maje karo 🤘</p>
                                    </div>
                                )}
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </AuthenticatedLayout>
    );
}
